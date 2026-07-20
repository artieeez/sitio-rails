class PassengersController < ApplicationController
  include TripScoped

  before_action :set_passenger, only: %i[ show edit update ]

  def index
    @include_removed = ActiveModel::Type::Boolean.new.cast(params[:include_removed])
    @passengers = @trip.passengers.listed(include_removed: @include_removed)
  end

  def show
  end

  def new
    @passenger = @trip.passengers.new
  end

  def create
    @passenger = @trip.passengers.new(passenger_params)

    if @passenger.save
      redirect_to trip_passenger_path(@trip, @passenger), notice: "Passageiro criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @passenger.update(passenger_params)
      redirect_to trip_passenger_path(@trip, @passenger), notice: "Passageiro atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_passenger
      @passenger = @trip.passengers.find(params[:id])
    end

    def passenger_params
      params.require(:passenger).permit(
        :full_name, :cpf, :parent_name, :parent_phone_number, :parent_email,
        :expected_amount_override_minor, :confirm_name_duplicate
      )
    end
end
