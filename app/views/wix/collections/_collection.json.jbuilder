json.id wix_collection["id"] || wix_collection["_id"]
json.name wix_collection["name"]
json.visible wix_collection["visible"]
json.number_of_products wix_collection["numberOfProducts"]
json.image_url Wix::Media.image_url(wix_collection["media"])
