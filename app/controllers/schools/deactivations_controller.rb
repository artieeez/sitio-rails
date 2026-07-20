class Schools::DeactivationsController < ApplicationController
  include SchoolScoped

  def create
    @school.deactivate(user: Current.user)
    redirect_to schools_path, notice: "Escola desativada."
  end

  def destroy
    @school.activate
    redirect_to schools_path, notice: "Escola ativada."
  end
end
