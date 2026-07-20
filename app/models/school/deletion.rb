class School::Deletion
  class Error < StandardError; end
  class NotAllowed < Error; end

  def initialize(school)
    @school = school
  end

  def allowed?
    # M1: local hard-delete only. Wix product-count gates arrive with M2.
    true
  end

  def perform
    raise NotAllowed, "School cannot be deleted" unless allowed?

    @school.destroy!
  end
end
