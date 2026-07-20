module Metadata::PageParser
  module_function

  MINOR_PER_MAJOR_UNIT = {
    "BRL" => 100,
    "USD" => 100,
    "EUR" => 100,
    "GBP" => 100,
    "JPY" => 1
  }.freeze

  def parse(html, page_url)
    title = json_ld_product_name(html) ||
      product_name_near_product_type(html) ||
      pick_meta(html, "property", "product:title") ||
      pick_meta(html, "property", "og:title") ||
      title_tag(html)

    description = pick_meta(html, "property", "og:description") ||
      pick_meta(html, "name", "description")

    og_image = pick_meta(html, "property", "og:image")
    image_url = og_image ? absolutize(og_image, page_url) : nil

    icon_href = favicon_href(html)
    favicon_url = if icon_href
      absolutize(icon_href, page_url)
    else
      URI.join(page_url.to_s, "/favicon.ico").to_s
    end

    price_amount = pick_meta(html, "property", "product:price:amount")
    price_currency = pick_meta(html, "property", "product:price:currency")
    default_expected_amount_minor = if price_amount.present?
      price_to_minor(price_amount, price_currency)
    end

    Metadata::PageFetch::Result.new(
      title:,
      description:,
      image_url:,
      favicon_url:,
      default_expected_amount_minor:
    )
  end

  def pick_meta(html, attr, key)
    escaped = Regexp.escape(key)
    re = /<meta[^>]+#{attr}=["']#{escaped}["'][^>]+content=["']([^"']*)["'][^>]*>/i
    re2 = /<meta[^>]+content=["']([^"']*)["'][^>]+#{attr}=["']#{escaped}["'][^>]*>/i
    html[re, 1] || html[re2, 1]
  end

  def title_tag(html)
    html[/<title[^>]*>([^<]*)<\/title>/i, 1]&.strip.presence
  end

  def favicon_href(html)
    html[/<link[^>]+rel=["'](?:shortcut )?icon["'][^>]+href=["']([^"']+)["']/i, 1] ||
      html[/<link[^>]+href=["']([^"']+)["'][^>]+rel=["'](?:shortcut )?icon["']/i, 1]
  end

  def product_name_near_product_type(html)
    forward = html[/"@type"\s*:\s*"Product"[\s\S]{0,8000}?"name"\s*:\s*"((?:[^"\\]|\\.)*)"/i, 1]
    return unescape_json_string(forward) if forward

    backward = html[/"name"\s*:\s*"((?:[^"\\]|\\.)*)"[\s\S]{0,8000}?"@type"\s*:\s*"Product"/i, 1]
    unescape_json_string(backward) if backward
  end

  def json_ld_product_name(html)
    html.scan(/<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i).each do |match|
      raw = match[0].to_s.strip
      next if raw.blank?

      data = JSON.parse(raw)
      name = find_product_name(data)
      return name if name
    rescue JSON::ParserError
      next
    end
    nil
  end

  def find_product_name(node)
    case node
    when Array
      node.each do |item|
        name = find_product_name(item)
        return name if name
      end
      nil
    when Hash
      name = resolve_product_name(node)
      return name if name

      if node["@graph"]
        name = find_product_name(node["@graph"])
        return name if name
      end

      if node["mainEntity"]
        name = find_product_name(node["mainEntity"])
        return name if name
      end

      node.each_value do |value|
        name = find_product_name(value)
        return name if name
      end
      nil
    end
  end

  def resolve_product_name(node)
    types = Array(node["@type"])
    product = types.any? { |type| type.is_a?(String) && (type == "Product" || type.end_with?("/Product", ":Product")) }
    return unless product

    name = node["name"]
    name.is_a?(String) && name.strip.presence
  end

  def price_to_minor(amount_str, currency)
    normalized = amount_str.to_s.gsub(/\s/, "").tr(",", ".")
    number = Float(normalized, exception: false)
    return if number.nil? || number.negative?

    code = currency.to_s.strip.upcase.presence || "BRL"
    factor = MINOR_PER_MAJOR_UNIT.fetch(code, 100)
    (number * factor).round
  end

  def absolutize(href, base)
    URI.join(base.to_s, href).to_s
  rescue URI::InvalidURIError
    href
  end

  def unescape_json_string(fragment)
    JSON.parse("\"#{fragment}\"")
  rescue JSON::ParserError
    fragment
  end
end
