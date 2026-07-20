class Trips::StoreConcealmentsController < ApplicationController
  include TripScoped

  def create
    @trip.conceal_in_store(user: Current.user)
    redirect_to school_trip_path(@trip.school, @trip), notice: "Viagem ocultada na loja Wix."
  end

  def destroy
    @trip.reveal_in_store
    redirect_to school_trip_path(@trip.school, @trip), notice: "Viagem exibida na loja Wix."
  rescue StoreConcealable::Inactive => error
    redirect_to school_trip_path(@trip.school, @trip), alert: error.message
  end
end
