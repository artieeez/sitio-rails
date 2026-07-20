module Authorization
  extend ActiveSupport::Concern

  class_methods do
    def require_admin_access(**options)
      before_action :require_admin!, **options
    end
  end

  private
    def require_admin!
      return if Current.user&.admin?

      head :forbidden
    end
end
