require "test_helper"

class TripsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    @school = schools(:active)
  end

  test "index lists trips for the school" do
    get school_trips_url(@school)
    assert_response :success
    assert_match trips(:active).title, response.body
    assert_no_match trips(:inactive).title, response.body
  end

  test "creates a trip under the school" do
    assert_difference -> { @school.trips.count }, 1 do
      post school_trips_url(@school), params: {
        trip: {
          title: "Nova Viagem",
          default_expected_amount_minor: 10_000
        }
      }
    end

    trip = @school.trips.order(:id).last
    assert_redirected_to school_trip_url(@school, trip)
    assert_equal "Nova Viagem", trip.title
  end

  test "updates a trip" do
    trip = trips(:active)
    patch school_trip_url(@school, trip), params: { trip: { title: "Atualizada" } }

    assert_redirected_to school_trip_url(@school, trip)
    assert_equal "Atualizada", trip.reload.title
  end
end
