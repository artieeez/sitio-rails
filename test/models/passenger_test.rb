require "test_helper"

class PassengerTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:active)
    @admin = users(:admin)
    @maria = passengers(:maria)
  end

  test "listed excludes removed passengers by default" do
    listed = @trip.passengers.listed

    assert_includes listed, @maria
    assert_not_includes listed, passengers(:removed)
  end

  test "remove and restore via Removal record" do
    @maria.remove(user: @admin)
    @maria.reload
    assert @maria.removed?

    @maria.restore
    @maria.reload
    assert_not @maria.removed?
  end

  test "manual settlement mark and clear" do
    @maria.mark_manual_settlement(user: @admin)
    assert @maria.reload.manually_settled?

    @maria.clear_manual_settlement
    assert_not @maria.reload.manually_settled?
  end

  test "rejects duplicate CPF on the same trip including removed" do
    passenger = @trip.passengers.new(full_name: "Outro", cpf: "529.982.247-25")
    assert_not passenger.valid?
    assert_includes passenger.errors[:cpf_normalized], "has already been taken"
  end

  test "warns on duplicate name unless confirmed" do
    passenger = @trip.passengers.new(full_name: "Maria Silva", cpf: "153.509.460-56")
    assert_not passenger.valid?
    assert passenger.errors[:full_name].any?

    passenger.confirm_name_duplicate = true
    assert passenger.valid?
  end

  test "expected amount falls back to trip default" do
    assert_equal 15_000, @maria.expected_amount_minor
  end

  test "payment status is settled when paid total meets expected" do
    assert_equal Passenger::SETTLED_PAYMENTS, @maria.payment_status
    assert_equal 15_000, @maria.paid_total_minor
  end

  test "payment status is pending when underpaid" do
    assert_equal Passenger::PENDING, passengers(:joao).payment_status
  end

  test "manual settlement wins over payment totals" do
    passengers(:joao).mark_manual_settlement(user: @admin)
    assert_equal Passenger::SETTLED_MANUAL, passengers(:joao).reload.payment_status
  end

  test "payment status unavailable without expected amount" do
    trip = trips(:inactive)
    passenger = trip.passengers.create!(full_name: "Sem Esperado", confirm_name_duplicate: true)
    assert_equal Passenger::UNAVAILABLE, passenger.payment_status
  end

  test "blocks trip deletion while passengers exist" do
    deletion = @trip.deletion
    assert_not deletion.allowed?
    assert_raises(Trip::Deletion::NotAllowed) { deletion.perform }
  end
end
