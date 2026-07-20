module PassengerScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_passenger
  end

  private
    def set_passenger
      @passenger = Passenger.find(params[:passenger_id])
    end
end
