class WixIntegration < ApplicationRecord
  SINGLETON_ID = 1
  PRIVATE_KEY_PREFIX_LENGTH = 10

  normalizes :site_id, :private_api_key, with: ->(value) {
    if value.blank?
      nil
    else
      value.strip
    end
  }
  normalizes :public_key, with: ->(value) {
    if value.blank?
      nil
    else
      WixIntegration.normalize_pem_public_key(value.strip)
    end
  }

  def self.instance = find_or_create_by!(id: SINGLETON_ID)

  def self.normalize_pem_public_key(value)
    base64 = value.gsub(/-----.*?-----/m, "").gsub(/\s+/, "")
    return value if base64.blank?

    lines = base64.scan(/.{1,64}/)
    "-----BEGIN PUBLIC KEY-----\n#{lines.join("\n")}\n-----END PUBLIC KEY-----"
  end

  def resolve_site_id = ENV["WIX_SITE_ID"].presence || site_id

  def resolve_private_api_key = ENV["WIX_PRIVATE_API_KEY"].presence || private_api_key

  def resolve_public_key = ENV["WIX_PUBLIC_KEY"].presence || public_key

  def private_api_key_prefix = resolve_private_api_key&.first(PRIVATE_KEY_PREFIX_LENGTH)

  def env_overridden?(field)
    case field
    when :site_id then ENV["WIX_SITE_ID"].present?
    when :private_api_key then ENV["WIX_PRIVATE_API_KEY"].present?
    when :public_key then ENV["WIX_PUBLIC_KEY"].present?
    else false
    end
  end
end
