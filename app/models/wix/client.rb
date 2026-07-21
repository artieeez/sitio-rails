# Faraday client for the Wix Stores Catalog v1 (read + write), site list, and
# media upload APIs. Credentials come from WixIntegration#resolve_* (ENV first,
# then the WixIntegration singleton row).
class Wix::Client
  class Error < StandardError
    attr_reader :status, :response_body

    def initialize(message, status: nil, response_body: nil)
      super(message)
      @status = status
      @response_body = response_body
    end

    def self.from_response(response)
      reason = extract_reason(response.body)
      message = "Wix API request failed with status: #{response.status}"
      message += " (#{reason})" if reason.present?
      new(message, status: response.status, response_body: response.body)
    end

    def self.extract_reason(body)
      return nil unless body.is_a?(Hash)

      body["message"] || body.dig("details", "applicationError", "description")
    end
  end

  class ApiKeyMissing < Error
    def initialize(message = "Wix private API key is not configured")
      super(message)
    end
  end

  class NotFound < Error; end
  class UpstreamError < Error; end

  READER_BASE = "https://www.wixapis.com/stores-reader/v1"
  STORES_BASE = "https://www.wixapis.com/stores/v1"
  SITES_BASE = "https://www.wixapis.com/site-list/v2"
  MEDIA_BASE = "https://www.wixapis.com/site-media/v1"
  ECOM_BASE = "https://www.wixapis.com/ecom/v1"

  PRODUCT_AUTOCOMPLETE_RECENT_LIMIT = 5
  PRODUCT_AUTOCOMPLETE_SCAN_LIMIT = 50
  PRODUCT_AUTOCOMPLETE_RESULT_LIMIT = 20
  COLLECTION_AUTOCOMPLETE_LIMIT = 20

  def initialize(integration: WixIntegration.instance, connection: nil)
    @integration = integration
    @connection = connection || build_connection
  end

  def get_product(id)
    response = authenticated_get("#{READER_BASE}/products/#{id}")
    raise NotFound.from_response(response) if response.status == 404
    raise UpstreamError.from_response(response) unless success?(response)

    product = response.body.is_a?(Hash) ? response.body["product"] : nil
    raise UpstreamError.new("Wix getProduct returned an invalid body", status: response.status) unless product.is_a?(Hash)

    product
  end

  def get_order(id)
    response = authenticated_get("#{ECOM_BASE}/orders/#{id}")
    raise NotFound.from_response(response) if response.status == 404
    raise UpstreamError.from_response(response) unless success?(response)

    order = response.body.is_a?(Hash) ? response.body["order"] : nil
    raise UpstreamError.new("Wix getOrder returned an invalid body", status: response.status) unless order.is_a?(Hash)

    order
  end

  def get_collection(id)
    result = query_collections(query: { filter: { id: { "$eq" => id } }.to_json, paging: { limit: 1, offset: 0 } })
    Array(result["collections"]).first
  end

  def query_collections(body)
    response = authenticated_post("#{READER_BASE}/collections/query", body)
    raise UpstreamError.from_response(response) unless success?(response)

    result = response.body
    raise UpstreamError.new("Wix queryCollections returned an invalid body", status: response.status) unless result.is_a?(Hash) && result["collections"].is_a?(Array)

    result
  end

  def query_products(body)
    response = authenticated_post("#{READER_BASE}/products/query", body)
    raise UpstreamError.from_response(response) unless success?(response)

    result = response.body
    raise UpstreamError.new("Wix queryProducts returned an invalid body", status: response.status) unless result.is_a?(Hash) && result["products"].is_a?(Array)

    result
  end

  def search_collections_by_prefix(prefix)
    p = prefix.to_s.strip
    return [] if p.empty?

    result = query_collections(query: {
      filter: { name: { "$startsWith" => p } }.to_json,
      sort: [ { fieldName: "name", order: "ASC" } ].to_json,
      paging: { limit: COLLECTION_AUTOCOMPLETE_LIMIT, offset: 0 }
    })
    result["collections"]
  end

  def search_products_in_collection_by_prefix(collection_id, prefix)
    filter = { "collections.id" => { "$in" => [ collection_id ] } }.to_json
    p = prefix.to_s.strip.downcase

    if p.empty?
      result = query_products(query: {
        filter:,
        sort: [ { fieldName: "lastUpdated", order: "DESC" } ].to_json,
        paging: { limit: PRODUCT_AUTOCOMPLETE_RECENT_LIMIT, offset: 0 }
      })
      return result["products"]
    end

    result = query_products(query: {
      filter:,
      sort: [ { fieldName: "name", order: "ASC" } ].to_json,
      paging: { limit: PRODUCT_AUTOCOMPLETE_SCAN_LIMIT, offset: 0 }
    })
    result["products"].select { |product| product["name"].to_s.downcase.start_with?(p) }.first(PRODUCT_AUTOCOMPLETE_RESULT_LIMIT)
  end

  def update_product(id, attrs)
    response = authenticated_patch("#{STORES_BASE}/products/#{id}", product: attrs.merge(id:))
    raise NotFound.from_response(response) if response.status == 404
    raise UpstreamError.from_response(response) unless success?(response)

    product = response.body.is_a?(Hash) ? response.body["product"] : nil
    raise UpstreamError.new("Wix updateProduct returned an invalid body", status: response.status) unless product.is_a?(Hash)

    product
  end

  def update_collection(id, attrs)
    response = authenticated_patch("#{STORES_BASE}/collections/#{id}", collection: attrs.merge(id:))
    raise NotFound.from_response(response) if response.status == 404
    raise UpstreamError.from_response(response) unless success?(response)

    collection = response.body.is_a?(Hash) ? response.body["collection"] : nil
    raise UpstreamError.new("Wix updateCollection returned an invalid body", status: response.status) unless collection.is_a?(Hash)

    collection
  end

  def delete_product(id)
    response = authenticated_delete("#{STORES_BASE}/products/#{id}")
    raise NotFound.from_response(response) if response.status == 404
    raise UpstreamError.from_response(response) unless success?(response)

    response.body
  end

  def delete_collection(id)
    response = authenticated_delete("#{STORES_BASE}/collections/#{id}")
    raise NotFound.from_response(response) if response.status == 404
    raise UpstreamError.from_response(response) unless success?(response)

    response.body
  end

  def generate_file_upload_url(body)
    response = authenticated_post("#{MEDIA_BASE}/files/generate-upload-url", body)
    raise UpstreamError.from_response(response) unless success?(response)

    result = response.body
    raise UpstreamError.new("Wix generateFileUploadUrl returned an invalid body", status: response.status) unless result.is_a?(Hash) && result["uploadUrl"].present?

    result
  end

  def list_sites
    response = authenticated_post(
      "#{SITES_BASE}/sites/query",
      { query: { filter: { trashedDate: { "$exists" => false } }, sort: [ { fieldName: "displayName", order: "ASC" } ] } },
      include_site_id: false
    )
    raise UpstreamError.from_response(response) unless success?(response)

    result = response.body
    raise UpstreamError.new("Wix listSites returned an invalid body", status: response.status) unless result.is_a?(Hash) && result["sites"].is_a?(Array)

    result["sites"]
  end

  private
    def authenticated_get(url)
      connection.get(url) { |req| apply_headers(req) }
    end

    def authenticated_post(url, body, include_site_id: true)
      connection.post(url, JSON.generate(body)) { |req| apply_headers(req, include_site_id:) }
    end

    def authenticated_patch(url, body)
      connection.patch(url, JSON.generate(body)) { |req| apply_headers(req) }
    end

    def authenticated_delete(url)
      connection.delete(url) { |req| apply_headers(req) }
    end

    def apply_headers(req, include_site_id: true)
      req.headers["Authorization"] = api_key
      req.headers["Accept"] = "application/json"
      req.headers["Content-Type"] = "application/json"

      if include_site_id
        site_id = @integration.resolve_site_id
        req.headers["wix-site-id"] = site_id if site_id.present?
      end
    end

    def api_key
      @integration.resolve_private_api_key.presence || raise(ApiKeyMissing.new)
    end

    def success?(response) = response.status >= 200 && response.status < 300

    def connection = @connection

    def build_connection
      require "faraday/response/json"

      Faraday.new do |f|
        f.response :json, content_type: /\bjson$/, parser_options: { symbolize_names: false }
        f.adapter Faraday.default_adapter
      end
    end
end
