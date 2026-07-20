class Schools::StoreConcealmentsController < ApplicationController
  include SchoolScoped

  def create
    @school.conceal_in_store(user: Current.user)
    redirect_to @school, notice: "Escola ocultada na loja Wix."
  end

  def destroy
    @school.reveal_in_store
    redirect_to @school, notice: "Escola exibida na loja Wix."
  rescue StoreConcealable::Inactive => error
    redirect_to @school, alert: error.message
  end
end
