class Metadata::PageFetchesController < ApplicationController
  def create
    result = Metadata::PageFetch.call(params.require(:url))
    render json: {
      title: result.title,
      description: result.description,
      image_url: result.image_url,
      favicon_url: result.favicon_url,
      default_expected_amount_minor: result.default_expected_amount_minor
    }, status: :created
  rescue Metadata::PageFetch::InvalidUrl => e
    render json: { message: e.message, code: e.code }, status: :bad_request
  rescue Metadata::PageFetch::SsrfBlocked => e
    render json: { message: e.message, code: e.code }, status: :bad_request
  rescue Metadata::PageFetch::UpstreamError => e
    render json: { message: e.message, code: e.code }, status: :bad_gateway
  end
end
