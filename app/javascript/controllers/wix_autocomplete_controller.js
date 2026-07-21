// Debounced Wix catalog autocomplete that fills linked form fields on pick.
//
// School collection example:
//   <div data-controller="wix-autocomplete"
//        data-wix-autocomplete-url-value="/wix/collections/autocomplete"
//        data-wix-autocomplete-show-url-value="/wix/collections/:id"
//        data-wix-autocomplete-min-length-value="1">
//     <input data-wix-autocomplete-target="query" data-action="input->wix-autocomplete#queue focus->wix-autocomplete#open">
//     <input type="hidden" data-wix-autocomplete-target="id" name="school[wix_collection_id]">
//     <ul data-wix-autocomplete-target="results" class="hidden"></ul>
//     <input data-wix-autocomplete-target="title">
//     <input data-wix-autocomplete-target="imageUrl">
//   </div>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "query", "id", "results", "title", "description", "imageUrl",
    "amountMinor", "slug", "productPageUrl", "mediaFileId", "status", "error"
  ]
  static values = {
    url: String,
    showUrl: { type: String, default: "" },
    schoolId: { type: String, default: "" },
    minLength: { type: Number, default: 1 },
    debounceMs: { type: Number, default: 320 }
  }

  connect() {
    this.generation = 0
    this.abortController = null
    this.items = []
  }

  disconnect() {
    this.clearTimer()
    this.abortInFlight()
  }

  open() {
    if (this.queryTarget.value.trim().length >= this.minLengthValue) {
      this.queue()
    }
  }

  queue() {
    this.clearTimer()
    this.timer = setTimeout(() => this.search(), this.debounceMsValue)
  }

  async search() {
    const prefix = this.queryTarget.value.trim()
    if (prefix.length < this.minLengthValue) {
      this.hideResults()
      this.hideError()
      return
    }

    this.generation += 1
    const generation = this.generation
    this.abortInFlight()
    this.abortController = new AbortController()
    this.showStatus()
    this.hideError()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("prefix", prefix)
      if (this.schoolIdValue) url.searchParams.set("school_id", this.schoolIdValue)

      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (generation !== this.generation) return

      if (!response.ok) {
        this.showError(response.status === 503
          ? "Integração Wix não configurada."
          : "Erro ao buscar no catálogo Wix.")
        this.hideResults()
        return
      }

      this.items = await response.json()
      this.renderResults()
    } catch (error) {
      if (error.name === "AbortError" || generation !== this.generation) return
      this.showError("Erro ao buscar no catálogo Wix.")
      this.hideResults()
    } finally {
      if (generation === this.generation) this.hideStatus()
    }
  }

  renderResults() {
    if (!this.hasResultsTarget) return

    this.resultsTarget.innerHTML = ""
    if (!this.items.length) {
      const empty = document.createElement("li")
      empty.className = "px-3 py-2 text-sm text-gray-500"
      empty.textContent = "Nenhum resultado."
      this.resultsTarget.appendChild(empty)
      this.resultsTarget.classList.remove("hidden")
      return
    }

    this.items.forEach((item, index) => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "w-full text-left px-3 py-2 text-sm hover:bg-gray-50"
      button.dataset.action = "wix-autocomplete#pick"
      button.dataset.index = String(index)
      button.innerHTML = `<span class="font-medium">${this.escape(item.name || item.id)}</span>`
      if (item.slug) {
        button.innerHTML += ` <span class="text-xs text-gray-500 font-mono">${this.escape(item.slug)}</span>`
      }
      li.appendChild(button)
      this.resultsTarget.appendChild(li)
    })
    this.resultsTarget.classList.remove("hidden")
  }

  async pick(event) {
    const index = Number(event.currentTarget.dataset.index)
    const item = this.items[index]
    if (!item) return

    this.idTarget.value = item.id
    this.queryTarget.value = item.name || item.id
    this.hideResults()

    if (this.hasTitleTarget && item.name) this.titleTarget.value = item.name
    if (this.hasImageUrlTarget && item.image_url) this.imageUrlTarget.value = item.image_url

    if (this.showUrlValue) {
      await this.fillFromShow(item.id)
    }
  }

  clear() {
    this.idTarget.value = ""
    this.queryTarget.value = ""
    this.hideResults()
  }

  async fillFromShow(id) {
    const path = this.showUrlValue.replace(":id", encodeURIComponent(id))
    try {
      const response = await fetch(path, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const detail = await response.json()

      if (this.hasTitleTarget && detail.name) this.titleTarget.value = detail.name
      if (this.hasDescriptionTarget && detail.description != null) this.descriptionTarget.value = detail.description
      if (this.hasImageUrlTarget && detail.image_url) this.imageUrlTarget.value = detail.image_url
      if (this.hasSlugTarget && detail.slug) this.slugTarget.value = detail.slug
      if (this.hasProductPageUrlTarget && detail.product_page_url) this.productPageUrlTarget.value = detail.product_page_url
      if (this.hasMediaFileIdTarget && detail.wix_media_file_id) this.mediaFileIdTarget.value = detail.wix_media_file_id
      if (this.hasAmountMinorTarget && detail.default_expected_amount_minor != null) {
        this.amountMinorTarget.value = detail.default_expected_amount_minor
      } else if (this.hasAmountMinorTarget && detail.price != null) {
        this.amountMinorTarget.value = Math.round(Number(detail.price) * 100)
      }
    } catch {
      // Keep autocomplete values already applied.
    }
  }

  escape(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  clearTimer() {
    if (this.timer) clearTimeout(this.timer)
  }

  abortInFlight() {
    if (this.abortController) this.abortController.abort()
  }

  hideResults() {
    if (this.hasResultsTarget) this.resultsTarget.classList.add("hidden")
  }

  showStatus() {
    if (this.hasStatusTarget) this.statusTarget.classList.remove("hidden")
  }

  hideStatus() {
    if (this.hasStatusTarget) this.statusTarget.classList.add("hidden")
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
