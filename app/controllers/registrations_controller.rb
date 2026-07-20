class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    redirect_to new_session_path unless User.count.zero?
  end

  def create
    return redirect_to new_session_path unless User.count.zero?

    user = User.new(registration_params.merge(role: :admin))
    if user.save
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_registration_path, alert: user.errors.full_messages.to_sentence
    end
  end

  private
    def registration_params
      params.permit(:email_address, :password, :password_confirmation)
    end
end
