json.partial! "wix/products/product", product: @product
json.description Wix::ProductDescription.to_html(@product["description"])
json.wix_media_file_id Wix::Media.file_id(@product["media"])
json.product_page_url begin
  page = @product["productPageUrl"]
  if page.is_a?(Hash)
    base = page["base"].to_s.sub(%r{/*\z}, "")
    path = page["path"].to_s
    path = "/#{path}" unless path.start_with?("/")
    "#{base}#{path}" if base.present?
  elsif page.is_a?(String)
    page.presence
  end
end
json.default_expected_amount_minor begin
  price = @product.dig("priceData", "price")
  price.nil? ? nil : (Float(price) * 100).round
rescue ArgumentError, TypeError
  nil
end
