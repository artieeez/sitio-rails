class Trip::Deletion
  class Error < StandardError; end
  class NotAllowed < Error; end

  def initialize(trip)
    @trip = trip
  end

  def passenger_count
    @trip.passengers.count
  end

  def allowed?
    passenger_count.zero?
  end

  def perform
    raise NotAllowed, "Trip still has passengers" unless allowed?

    @trip.destroy!
  end
end
