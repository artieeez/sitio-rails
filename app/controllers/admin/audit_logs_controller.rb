module Admin
  class AuditLogsController < ApplicationController
    before_action :require_admin!

    def index
      @audit_logs = AuditLog.paginate(page: params[:page])
    end

    def show
      @audit_log = AuditLog.find(params[:id])
    end
  end
end
