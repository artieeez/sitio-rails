require "test_helper"

class Wix::MediaTest < ActiveSupport::TestCase
  test "image_url reads the main media image url" do
    media = { "mainMedia" => { "image" => { "id" => "img-1", "url" => "https://static.wixstatic.com/img-1.jpg" } } }

    assert_equal "https://static.wixstatic.com/img-1.jpg", Wix::Media.image_url(media)
  end

  test "image_url falls back to the thumbnail when there is no image" do
    media = { "mainMedia" => { "thumbnail" => { "url" => "https://static.wixstatic.com/thumb.jpg" } } }

    assert_equal "https://static.wixstatic.com/thumb.jpg", Wix::Media.image_url(media)
  end

  test "image_url is nil for blank or malformed media" do
    assert_nil Wix::Media.image_url(nil)
    assert_nil Wix::Media.image_url({})
    assert_nil Wix::Media.image_url({ "mainMedia" => {} })
  end

  test "file_id reads the main media image id" do
    media = { "mainMedia" => { "image" => { "id" => "img-1" } } }

    assert_equal "img-1", Wix::Media.file_id(media)
  end

  test "file_id falls back to _id when id is absent" do
    media = { "mainMedia" => { "image" => { "_id" => "img-2" } } }

    assert_equal "img-2", Wix::Media.file_id(media)
  end
end
