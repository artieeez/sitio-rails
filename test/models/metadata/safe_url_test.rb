require "test_helper"

class Metadata::SafeUrlTest < ActiveSupport::TestCase
  test "blocks localhost" do
    assert_raises Metadata::PageFetch::SsrfBlocked do
      Metadata::SafeUrl.assert!(URI.parse("http://localhost/"))
    end
  end

  test "blocks 127.0.0.1" do
    assert_raises Metadata::PageFetch::SsrfBlocked do
      Metadata::SafeUrl.assert!(URI.parse("http://127.0.0.1/"))
    end
  end

  test "blocks urls with embedded credentials" do
    assert_raises Metadata::PageFetch::InvalidUrl do
      Metadata::SafeUrl.assert!(URI.parse("http://user:pass@example.com/"))
    end
  end

  test "blocks non-http(s) schemes like file" do
    assert_raises Metadata::PageFetch::InvalidUrl do
      Metadata::SafeUrl.assert!(URI.parse("file:///etc/passwd"))
    end
  end

  test "blocks the cloud metadata hostname" do
    assert_raises Metadata::PageFetch::SsrfBlocked do
      Metadata::SafeUrl.assert!(URI.parse("http://metadata.google.internal/"))
    end
  end

  test "blocks the cloud metadata IP literal" do
    assert_raises Metadata::PageFetch::SsrfBlocked do
      Metadata::SafeUrl.assert!(URI.parse("http://169.254.169.254/"))
    end
  end

  test "blocks private IPv4 ranges" do
    assert_raises Metadata::PageFetch::SsrfBlocked do
      Metadata::SafeUrl.assert!(URI.parse("http://10.0.0.5/"))
    end
  end

  test "allows a public IP literal without a DNS lookup" do
    assert_nothing_raised do
      Metadata::SafeUrl.assert!(URI.parse("http://8.8.8.8/"))
    end
  end

  test "rejects a blank host" do
    assert_raises Metadata::PageFetch::InvalidUrl do
      Metadata::SafeUrl.assert!(URI.parse("http:///path"))
    end
  end
end
