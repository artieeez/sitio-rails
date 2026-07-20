require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  setup do
    @maria = passengers(:maria)
    @joao = passengers(:joao)
  end

  test "chronological orders by paid_on then created_at" do
    assert_equal [ payments(:wix_payment), payments(:maria_full) ], @maria.payments.chronological.to_a
  end

  test "rejects create when passenger is removed" do
    payment = passengers(:removed).payments.new(
      amount_minor: 1000,
      paid_on: Date.current,
      location: "Loja",
      payer_identity: "Alguém"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:passenger], "was removed"
  end

  test "trims location and payer identity" do
    payment = @joao.payments.create!(
      amount_minor: 100,
      paid_on: Date.current,
      location: "  Banco  ",
      payer_identity: "  Pai  "
    )

    assert_equal "Banco", payment.location
    assert_equal "Pai", payment.payer_identity
  end

  test "wix transaction id is unique" do
    payment = @joao.payments.new(
      amount_minor: 100,
      paid_on: Date.current,
      location: "wix",
      payer_identity: "Wix",
      wix_transaction_id: "wix-txn-fixture-1"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:wix_transaction_id], "has already been taken"
  end
end
