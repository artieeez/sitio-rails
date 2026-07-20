class DashboardController < ApplicationController
  require_admin_access only: :admin_demo

  def index
  end

  def admin_demo
  end
end
