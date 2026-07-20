require "test_helper"

class TripTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @active = trips(:active)
    @inactive = trips(:inactive)
    @expired = trips(:expired)
  end

  test "listed excludes inactive trips by default" do
    listed = Trip.listed

    assert_includes listed, @active
    assert_includes listed, @expired
    assert_not_includes listed, @inactive
  end

  test "deactivating conceals the store listing" do
    @active.deactivate(user: @admin)
    @active.reload

    assert @active.deactivated?
    assert @active.store_concealed?
  end

  test "conceal_expired_in_store_now hides expired visible trips" do
    assert @expired.store_visible?

    Trip.conceal_expired_in_store_now
    @expired.reload

    assert @expired.store_concealed?
    assert @expired.active?
  end

  test "deletion is allowed when there are no passengers" do
    trip = trips(:active).school.trips.create!(title: "Sem passageiros")
    assert trip.deletion.allowed?

    assert_difference -> { Trip.count }, -1 do
      trip.deletion.perform
    end
  end

  test "belongs to school" do
    assert_equal schools(:active), @active.school
  end
end
