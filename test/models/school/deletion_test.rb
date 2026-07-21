require "test_helper"

class School::DeletionTest < ActiveSupport::TestCase
  class FakeClient
    def initialize(collection: nil, error: nil)
      @collection = collection
      @error = error
    end

    def get_collection(_id)
      raise @error if @error

      @collection
    end
  end

  test "is allowed when the school has no Wix collection" do
    school = schools(:inactive)

    assert school.deletion.allowed?
  end

  test "is allowed when the Wix collection has zero products" do
    school = schools(:active)
    deletion = School::Deletion.new(school, client: FakeClient.new(collection: { "numberOfProducts" => 0 }))

    assert deletion.allowed?
  end

  test "is allowed when the Wix collection no longer exists upstream" do
    school = schools(:active)
    deletion = School::Deletion.new(school, client: FakeClient.new(collection: nil))

    assert deletion.allowed?
  end

  test "is not allowed when the Wix collection still has products" do
    school = schools(:active)
    deletion = School::Deletion.new(school, client: FakeClient.new(collection: { "numberOfProducts" => 2 }))

    assert_not deletion.allowed?
  end

  test "soft-fails permissive when the Wix API key is not configured" do
    school = schools(:active)
    deletion = School::Deletion.new(school, client: FakeClient.new(error: Wix::Client::ApiKeyMissing.new))

    assert deletion.allowed?
  end

  test "is not allowed when the Wix API errors upstream" do
    school = schools(:active)
    deletion = School::Deletion.new(school, client: FakeClient.new(error: Wix::Client::UpstreamError.new("boom", status: 500)))

    assert_not deletion.allowed?
  end

  test "perform destroys the school when allowed" do
    school = schools(:inactive)

    assert_difference "School.count", -1 do
      School::Deletion.new(school).perform
    end
  end

  test "perform raises NotAllowed and does not destroy the school when blocked" do
    school = schools(:active)
    deletion = School::Deletion.new(school, client: FakeClient.new(collection: { "numberOfProducts" => 1 }))

    assert_raises(School::Deletion::NotAllowed) { deletion.perform }
    assert School.exists?(school.id)
  end
end
