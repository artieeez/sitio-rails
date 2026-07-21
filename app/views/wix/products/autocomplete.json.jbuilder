json.array! @products do |product|
  json.partial! "wix/products/product", product:
end
