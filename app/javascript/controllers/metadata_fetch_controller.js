// Fetches page metadata (favicon) when the school URL field changes.
//
//   <div data-controller="metadata-fetch"
//        data-metadata-fetch-url-value="/metadata/page_fetch"
//        data-metadata-fetch-baseline-url-value="https://example.com">
//     <input data-metadata-fetch-target="url" data-action="input->metadata-fetch#queue">
//     <input data-metadata-fetch-target="favicon">
//     <span data-metadata-fetch-target="status" class="hidden">…</span>
//     <p data-metadata-fetch-target="error" class="hidden"></p>
//   </div>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "favicon", "status", "error"]
  static values = {
    url: String,
    baselineUrl: { type: String, default: "" },
    debounceMs: { type: Number, default: 600 }
  }

  connect() {
    this.generation = 0
    this.abortController = null
  }

  disconnect() {
    this.clearTimer()
    this.abortInFlight()
  }

  queue() {
    this.clearTimer()
    this.timer = setTimeout(() => this.fetchMetadata(), this.debounceMsValue)
  }

  async fetchMetadata() {
    const pageUrl = this.urlTarget.value.trim()
    if (!pageUrl || pageUrl === this.baselineUrlValue.trim()) {
      this.hideStatus()
      this.hideError()
      return
    }

    if (!this.isValidHttpUrl(pageUrl)) {
      return
    }

    this.generation += 1
    const generation = this.generation
    this.abortInFlight()
    this.abortController = new AbortController()

    this.showStatus()
    this.hideError()

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ url: pageUrl }),
        signal: this.abortController.signal
      })

      if (generation !== this.generation) return

      const payload = await response.json()
      if (!response.ok) {
        this.showError(response.status === 502
          ? "Não foi possível buscar a página. Preencha o favicon manualmente."
          : "Falha ao buscar favicon.")
        return
      }

      if (payload.favicon_url) {
        this.faviconTarget.value = payload.favicon_url
      }
    } catch (error) {
      if (error.name === "AbortError" || generation !== this.generation) return
      this.showError("Falha ao buscar favicon.")
    } finally {
      if (generation === this.generation) this.hideStatus()
    }
  }

  isValidHttpUrl(value) {
    try {
      const parsed = new URL(value)
      return parsed.protocol === "http:" || parsed.protocol === "https:"
    } catch {
      return false
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  clearTimer() {
    if (this.timer) clearTimeout(this.timer)
  }

  abortInFlight() {
    if (this.abortController) this.abortController.abort()
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
