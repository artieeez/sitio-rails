class TripsController < ApplicationController
  include SchoolScoped

  before_action :set_trip, only: %i[ show edit update ]

  def index
    @include_inactive = ActiveModel::Type::Boolean.new.cast(params[:include_inactive])
    @trips = @school.trips.listed(include_inactive: @include_inactive)
  end

  def show
  end

  def new
    @trip = @school.trips.new
  end

  def create
    @trip = @school.trips.new(trip_params)

    if @trip.save
      redirect_to school_trip_path(@school, @trip), notice: "Viagem criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @trip.update(trip_params)
      redirect_to school_trip_path(@school, @trip), notice: "Viagem atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_trip
      @trip = @school.trips.find(params[:id])
    end

    def trip_params
      params.require(:trip).permit(
        :title, :description, :image_url, :wix_product_id, :wix_product_slug,
        :wix_product_page_url, :wix_media_file_id, :default_expected_amount_minor,
        :expiration_date
      )
    end
end
