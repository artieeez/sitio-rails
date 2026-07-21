module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: %i[ edit update ]

    def index
      @users = User.order(:email_address)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      @user.role = requested_role
      if @user.save
        redirect_to admin_users_path, notice: "User was successfully created."
      else
        redirect_to new_admin_user_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      attributes = user_params
      if attributes[:password].blank?
        attributes = attributes.except(:password, :password_confirmation)
      end

      @user.assign_attributes(attributes)
      @user.role = requested_role
      if @user.save
        redirect_to admin_users_path, notice: "User was successfully updated."
      else
        redirect_to edit_admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
      end
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:email_address, :password, :password_confirmation)
      end

      def requested_role
        params.require(:user)[:role]
      end
  end
end
