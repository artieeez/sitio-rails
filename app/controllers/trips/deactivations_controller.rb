class Trips::DeactivationsController < ApplicationController
  include TripScoped

  def create
    @trip.deactivate(user: Current.user)
    redirect_to school_trips_path(@trip.school), notice: "Viagem desativada."
  end

  def destroy
    @trip.activate
    redirect_to school_trips_path(@trip.school), notice: "Viagem ativada."
  end
end
