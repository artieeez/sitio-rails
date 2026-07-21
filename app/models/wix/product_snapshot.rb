# Maps a raw Wix Stores product payload into the Trip snapshot columns, mirroring
# buildProductSnapshot in wix-webhook-event-handler.service.ts. Shared by
# Wix::CatalogSync (product create/change/drift-heal) and Wix::PaymentSync
# (auto-create from a payment when the trip doesn't exist yet).
class Wix::ProductSnapshot
  def self.build(product, product_id)
    {
      title: product["name"].presence || product_id,
      description: Wix::ProductDescription.to_html(product["description"]),
      image_url: Wix::Media.image_url(product["media"]),
      wix_media_file_id: Wix::Media.file_id(product["media"]),
      wix_product_slug: product["slug"],
      wix_product_page_url: page_url(product),
      default_expected_amount_minor: price_minor(product)
    }
  end

  def self.page_url(product)
    raw = product["productPageUrl"]
    if raw.is_a?(Hash)
      page_url_from_parts(raw)
    elsif raw.is_a?(String) && raw.strip.present?
      raw.strip
    end
  end

  def self.page_url_from_parts(parts)
    base = parts["base"].to_s.strip.sub(%r{/+\z}, "")
    path = parts["path"].to_s.strip
    if base.present? && path.present?
      "#{base}#{path.start_with?("/") ? path : "/#{path}"}"
    elsif base.present?
      base
    elsif path.match?(%r{\Ahttps?://}i)
      path
    end
  end

  def self.price_minor(product)
    price = product.dig("priceData", "price")
    return nil if price.nil?

    (price.to_f * 100).round
  end
  private_class_method :page_url, :page_url_from_parts, :price_minor
end
