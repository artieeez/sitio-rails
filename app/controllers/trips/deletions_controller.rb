class Trips::DeletionsController < ApplicationController
  include TripScoped

  def show
    @deletion = @trip.deletion
  end

  def destroy
    school = @trip.school
    @trip.deletion.perform
    redirect_to school_trips_path(school), notice: "Viagem excluída."
  rescue Trip::Deletion::NotAllowed => error
    redirect_to trip_deletion_path(@trip), alert: error.message
  end
end
