# Best-effort extraction of the main image URL / Wix Media Manager file id from
# a Wix Stores `media` payload (`media.mainMedia.image` or `.thumbnail`).
class Wix::Media
  def self.image_url(media) = from_node(main_media(media), "url")
  def self.file_id(media) = from_node(main_media(media), "id") || from_node(main_media(media), "_id")

  def self.main_media(media)
    return nil unless media.is_a?(Hash)

    media["mainMedia"]
  end

  def self.from_node(main, key)
    return nil unless main.is_a?(Hash)

    value = node_value(main["image"], key) || node_value(main["thumbnail"], key)
    value.presence
  end

  def self.node_value(node, key)
    return nil unless node.is_a?(Hash)

    value = node[key]
    value.is_a?(String) ? value : nil
  end
  private_class_method :main_media, :from_node, :node_value
end
