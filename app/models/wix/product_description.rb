# Wix Stores product descriptions are either a plain string or Ricos rich
# content (a JSON object, or a JSON-encoded string of one). This is a minimal,
# best-effort Ricos -> HTML port of wix-product-description-html.ts; anything
# that isn't a Ricos document passes through as-is.
class Wix::ProductDescription
  def self.to_html(description) = new(description).to_html

  def initialize(description)
    @description = description
  end

  def to_html
    if @description.is_a?(String)
      string_to_html(@description)
    elsif @description.is_a?(Hash)
      ricos_document?(@description) ? document_to_html(@description) : nil
    else
      nil
    end
  end

  private
    def string_to_html(text)
      trimmed = text.strip
      return nil if trimmed.blank?

      parsed = parse_json_object(trimmed)
      if parsed && ricos_document?(parsed)
        document_to_html(parsed)
      else
        trimmed
      end
    end

    def parse_json_object(text)
      return nil unless text.start_with?("{")

      parsed = JSON.parse(text)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def ricos_document?(hash) = hash["nodes"].is_a?(Array)

    def document_to_html(document)
      html = Array(document["nodes"]).map { |node| node_to_html(node) }.join.strip
      html.presence
    end

    def node_to_html(node)
      return "" unless node.is_a?(Hash)

      children = Array(node["nodes"]).map { |child| node_to_html(child) }.join

      case node["type"]
      when "PARAGRAPH" then "<p>#{children.presence || "<br>"}</p>"
      when "TEXT" then text_node_to_html(node)
      when "HEADING" then heading_node_to_html(node, children)
      when "BULLETED_LIST" then "<ul>#{children}</ul>"
      when "ORDERED_LIST" then "<ol>#{children}</ol>"
      when "LIST_ITEM" then "<li>#{children}</li>"
      when "BLOCKQUOTE" then "<blockquote>#{children}</blockquote>"
      when "DIVIDER" then "<hr>"
      when "LINE_SPACER" then "<p><br></p>"
      else children
      end
    end

    def text_node_to_html(node)
      text_data = node["textData"] || {}
      escaped = ERB::Util.html_escape(text_data["text"].to_s)
      apply_decorations(escaped, text_data["decorations"])
    end

    def apply_decorations(text, decorations)
      return text unless decorations.is_a?(Array)

      decorations.reduce(text) do |out, decoration|
        next out unless decoration.is_a?(Hash)

        case decoration["type"]
        when "BOLD" then "<strong>#{out}</strong>"
        when "ITALIC" then "<em>#{out}</em>"
        when "UNDERLINE" then "<u>#{out}</u>"
        else out
        end
      end
    end

    def heading_node_to_html(node, children)
      level = node.dig("headingData", "level")
      level = 2 unless level.is_a?(Integer) && level.between?(1, 6)
      "<h#{level}>#{children}</h#{level}>"
    end
end
