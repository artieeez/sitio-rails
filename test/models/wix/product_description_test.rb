require "test_helper"

class Wix::ProductDescriptionTest < ActiveSupport::TestCase
  test "returns nil for a blank description" do
    assert_nil Wix::ProductDescription.to_html(nil)
    assert_nil Wix::ProductDescription.to_html("   ")
  end

  test "passes a plain string through as-is" do
    assert_equal "Uma viagem incrível", Wix::ProductDescription.to_html("Uma viagem incrível")
  end

  test "converts a Ricos document hash into HTML" do
    document = {
      "nodes" => [
        {
          "type" => "PARAGRAPH",
          "nodes" => [
            { "type" => "TEXT", "textData" => { "text" => "Olá", "decorations" => [ { "type" => "BOLD" } ] } }
          ]
        }
      ]
    }

    assert_equal "<p><strong>Olá</strong></p>", Wix::ProductDescription.to_html(document)
  end

  test "converts a JSON-encoded Ricos document string into HTML" do
    document = { "nodes" => [ { "type" => "PARAGRAPH", "nodes" => [ { "type" => "TEXT", "textData" => { "text" => "Oi" } } ] } ] }.to_json

    assert_equal "<p>Oi</p>", Wix::ProductDescription.to_html(document)
  end

  test "escapes HTML in text nodes" do
    document = { "nodes" => [ { "type" => "PARAGRAPH", "nodes" => [ { "type" => "TEXT", "textData" => { "text" => "<script>" } } ] } ] }

    assert_equal "<p>&lt;script&gt;</p>", Wix::ProductDescription.to_html(document)
  end

  test "renders headings, lists, and dividers" do
    document = {
      "nodes" => [
        { "type" => "HEADING", "headingData" => { "level" => 3 }, "nodes" => [ { "type" => "TEXT", "textData" => { "text" => "Título" } } ] },
        { "type" => "BULLETED_LIST", "nodes" => [ { "type" => "LIST_ITEM", "nodes" => [ { "type" => "TEXT", "textData" => { "text" => "Item" } } ] } ] },
        { "type" => "DIVIDER" }
      ]
    }

    assert_equal "<h3>Título</h3><ul><li>Item</li></ul><hr>", Wix::ProductDescription.to_html(document)
  end
end
