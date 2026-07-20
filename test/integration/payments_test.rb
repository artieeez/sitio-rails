require "test_helper"

class PaymentsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    @passenger = passengers(:maria)
  end

  test "index lists payments for passenger" do
    get passenger_payments_url(@passenger)
    assert_response :success
    assert_match "Banco", response.body
    assert_match "Ana Silva", response.body
  end

  test "creates a payment" do
    assert_difference -> { @passenger.payments.count }, 1 do
      post passenger_payments_url(@passenger), params: {
        payment: {
          amount_minor: 2500,
          paid_on: "2026-07-15",
          location: "Caixa",
          payer_identity: "Responsável"
        }
      }
    end

    assert_redirected_to passenger_payments_url(@passenger)
    payment = @passenger.payments.order(:id).last
    assert_equal 2500, payment.amount_minor
    assert_equal "Caixa", payment.location
  end

  test "updates a payment" do
    payment = payments(:joao_partial)
    passenger = passengers(:joao)

    patch passenger_payment_url(passenger, payment), params: {
      payment: {
        amount_minor: 8000,
        paid_on: "2026-07-12",
        location: "Loja",
        payer_identity: "João Souza"
      }
    }

    assert_redirected_to passenger_payments_url(passenger)
    assert_equal 8000, payment.reload.amount_minor
  end

  test "destroys a payment" do
    payment = payments(:joao_partial)
    passenger = passengers(:joao)

    assert_difference -> { passenger.payments.count }, -1 do
      delete passenger_payment_url(passenger, payment)
    end

    assert_redirected_to passenger_payments_url(passenger)
  end

  test "does not create payment for removed passenger" do
    passenger = passengers(:removed)

    assert_no_difference -> { Payment.count } do
      post passenger_payments_url(passenger), params: {
        payment: {
          amount_minor: 1000,
          paid_on: "2026-07-15",
          location: "Loja",
          payer_identity: "Alguém"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
