class Wix::CollectionsController < ApplicationController
  include WixClientErrors

  def autocomplete
    @collections = Wix::Client.new.search_collections_by_prefix(params[:prefix])
  end

  def show
    @collection = Wix::Client.new.get_collection(params[:id])
    head :not_found if @collection.nil?
  end
end
