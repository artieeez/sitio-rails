class Passengers::RemovalsController < ApplicationController
  include PassengerScoped

  def create
    @passenger.remove(user: Current.user)
    redirect_to trip_passengers_path(@passenger.trip), notice: "Passageiro removido."
  end

  def destroy
    @passenger.restore
    redirect_to trip_passengers_path(@passenger.trip), notice: "Passageiro restaurado."
  end
end
