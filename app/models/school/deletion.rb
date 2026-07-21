class School::Deletion
  class Error < StandardError; end
  class NotAllowed < Error; end

  def initialize(school, client: nil)
    @school = school
    @client = client
  end

  def allowed?
    return true if @school.wix_collection_id.blank?

    collection = client.get_collection(@school.wix_collection_id)
    collection.nil? || (collection["numberOfProducts"] || 0).zero?
  rescue Wix::Client::ApiKeyMissing
    # No Wix credentials configured: soft-fail permissive, allow the local delete.
    true
  rescue Wix::Client::Error
    false
  end

  def perform
    raise NotAllowed, "School cannot be deleted" unless allowed?

    @school.destroy!
  end

  private
    def client = @client ||= Wix::Client.new
end
