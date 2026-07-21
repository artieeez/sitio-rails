json.array! @collections do |collection|
  json.partial! "wix/collections/collection", wix_collection: collection
end
