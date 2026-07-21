module Metadata::SafeUrl
  module_function

  METADATA_HOST_BLOCKLIST = Set["metadata.google.internal", "169.254.169.254"].freeze

  def assert!(uri)
    raise Metadata::PageFetch::InvalidUrl, "URL must not include credentials" if uri.user || uri.password
    raise Metadata::PageFetch::InvalidUrl, "Only http(s) URLs are allowed" unless %w[ http https ].include?(uri.scheme)

    host = uri.host.to_s.downcase
    raise Metadata::PageFetch::InvalidUrl if host.blank?

    if METADATA_HOST_BLOCKLIST.include?(host) || blocked_hostname?(host)
      raise Metadata::PageFetch::SsrfBlocked
    end

    if ip_literal?(host)
      raise Metadata::PageFetch::SsrfBlocked, "Address not allowed" if blocked_ip?(host)
    else
      assert_resolved_addresses_safe!(host)
    end
  end

  def blocked_hostname?(host)
    host == "localhost" || host.end_with?(".localhost")
  end

  def ip_literal?(host)
    !!(IPAddr.new(host) rescue nil)
  end

  def assert_resolved_addresses_safe!(host)
    addresses = Resolv.getaddresses(host)
    raise Metadata::PageFetch::InvalidUrl, "Could not resolve host" if addresses.empty?

    addresses.each do |address|
      raise Metadata::PageFetch::SsrfBlocked, "Resolved address not allowed" if blocked_ip?(address)
    end
  rescue Resolv::ResolvError
    raise Metadata::PageFetch::InvalidUrl, "Could not resolve host"
  end

  def blocked_ip?(ip)
    addr = IPAddr.new(ip)
    return true if addr == IPAddr.new("0.0.0.0") || addr == IPAddr.new("::")
    return true if addr.loopback?
    return true if addr.link_local?
    return true if private_ipv4?(addr)
    return true if unique_local_ipv6?(addr)
    return true if addr.ipv4_mapped? && blocked_ip?(addr.native.to_s)

    false
  rescue IPAddr::InvalidAddressError
    false
  end

  def private_ipv4?(addr)
    return false unless addr.ipv4?

    IPAddr.new("10.0.0.0/8").include?(addr) ||
      IPAddr.new("172.16.0.0/12").include?(addr) ||
      IPAddr.new("192.168.0.0/16").include?(addr)
  end

  def unique_local_ipv6?(addr)
    return false unless addr.ipv6?

    IPAddr.new("fc00::/7").include?(addr)
  end
end
