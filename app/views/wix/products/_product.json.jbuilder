json.id product["id"] || product["_id"]
json.name product["name"]
json.slug product["slug"]
json.visible product["visible"]
json.image_url Wix::Media.image_url(product["media"])
json.price product.dig("priceData", "price")
