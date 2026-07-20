require "test_helper"

class PassengersTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    @trip = trips(:active)
  end

  test "index lists present passengers" do
    get trip_passengers_url(@trip)
    assert_response :success
    assert_match passengers(:maria).full_name, response.body
    assert_no_match passengers(:removed).full_name, response.body
  end

  test "creates a passenger" do
    assert_difference -> { @trip.passengers.count }, 1 do
      post trip_passengers_url(@trip), params: {
        passenger: {
          full_name: "Nova Pessoa",
          cpf: "153.509.460-56",
          parent_name: "Pai"
        }
      }
    end

    passenger = @trip.passengers.order(:id).last
    assert_redirected_to trip_passenger_url(@trip, passenger)
    assert_equal "15350946056", passenger.cpf_normalized
  end

  test "soft-removes a passenger" do
    passenger = passengers(:maria)
    post passenger_removal_url(passenger)

    assert_redirected_to trip_passengers_url(@trip)
    assert passenger.reload.removed?
  end
end
