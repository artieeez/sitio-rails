class Webhooks::WixController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    event_type, data = Wix::Webhook.verify_and_parse(request.raw_post)
    Wix::Event.ingest(event_type:, data:)
    head :ok
  rescue Wix::Webhook::InvalidSignature
    head :unauthorized
  rescue Wix::Webhook::MalformedEnvelope
    head :bad_request
  end
end
