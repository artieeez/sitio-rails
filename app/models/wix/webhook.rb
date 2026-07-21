# Verifies and decodes an inbound Wix webhook delivery. Wix sends the body as a
# raw RS256 JWT string; the JWT's `data` claim is a JSON string envelope whose
# own `data` field is, in turn, a JSON string carrying the event-specific payload.
class Wix::Webhook
  class Error < StandardError; end
  class InvalidSignature < Error; end
  class MalformedEnvelope < Error; end

  def self.verify_and_parse(raw_jwt, integration: WixIntegration.instance)
    new(raw_jwt, integration:).verify_and_parse
  end

  def initialize(raw_jwt, integration: WixIntegration.instance)
    @raw_jwt = raw_jwt
    @integration = integration
  end

  def verify_and_parse
    envelope = parse_envelope(decode_jwt)
    [ envelope["eventType"], parse_data(envelope) ]
  end

  private
    def decode_jwt
      public_key = @integration.resolve_public_key
      raise InvalidSignature, "Wix public key is not configured" if public_key.blank?

      rsa_key = OpenSSL::PKey::RSA.new(public_key)
      payload, = JWT.decode(@raw_jwt, rsa_key, true, algorithm: "RS256")
      payload
    rescue JWT::DecodeError, OpenSSL::PKey::PKeyError => e
      raise InvalidSignature, e.message
    end

    def parse_envelope(payload)
      raw = payload["data"]
      raise MalformedEnvelope, "missing data field" unless raw.is_a?(String)

      parsed = JSON.parse(raw)
      raise MalformedEnvelope, "data field is not a JSON object" unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      raise MalformedEnvelope, e.message
    end

    def parse_data(envelope)
      raw = envelope["data"]
      return {} unless raw.is_a?(String)

      parsed = JSON.parse(raw)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError => e
      raise MalformedEnvelope, e.message
    end
end
