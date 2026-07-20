module SchoolScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_school
  end

  private
    def set_school
      @school = School.find(params[:school_id])
    end
end
