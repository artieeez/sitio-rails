class Wix::ProductsController < ApplicationController
  include WixClientErrors

  def autocomplete
    school = School.find(params[:school_id])
    @products = if school.wix_collection_id.present?
      Wix::Client.new.search_products_in_collection_by_prefix(school.wix_collection_id, params[:prefix])
    else
      []
    end
  end

  def show
    @product = Wix::Client.new.get_product(params[:id])
  end
end
