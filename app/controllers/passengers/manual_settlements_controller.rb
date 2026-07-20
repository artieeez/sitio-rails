class Passengers::ManualSettlementsController < ApplicationController
  include PassengerScoped

  def create
    @passenger.mark_manual_settlement(user: Current.user)
    redirect_to trip_passenger_path(@passenger.trip, @passenger), notice: "Marcado como pago (sem informações)."
  end

  def destroy
    @passenger.clear_manual_settlement
    redirect_to trip_passenger_path(@passenger.trip, @passenger), notice: "Pagamento manual desmarcado."
  end
end
