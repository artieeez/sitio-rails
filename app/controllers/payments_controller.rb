class PaymentsController < ApplicationController
  include PassengerScoped

  before_action :set_payment, only: %i[ edit update destroy ]

  def index
    @payments = @passenger.payments.chronological
  end

  def new
    @payment = @passenger.payments.new(
      amount_minor: @passenger.expected_amount_minor,
      paid_on: Date.current
    )
  end

  def create
    @payment = @passenger.payments.new(payment_params)

    if @payment.save
      redirect_to passenger_payments_path(@passenger), notice: "Pagamento registrado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment.update(payment_params)
      redirect_to passenger_payments_path(@passenger), notice: "Pagamento atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment.destroy!
    redirect_to passenger_payments_path(@passenger), notice: "Pagamento excluído."
  end

  private
    def set_payment
      @payment = @passenger.payments.find(params[:id])
    end

    def payment_params
      params.require(:payment).permit(:amount_minor, :paid_on, :location, :payer_identity)
    end
end
