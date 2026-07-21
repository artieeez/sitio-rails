module Admin
  class WixEventsController < ApplicationController
    before_action :require_admin!

    LIMIT = 100

    def index
      @wix_events = Wix::Event.order(created_at: :desc).limit(LIMIT)
    end

    def show
      @wix_event = Wix::Event.find(params[:id])
    end
  end
end
