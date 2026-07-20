require "test_helper"

class SchoolTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @active = schools(:active)
    @inactive = schools(:inactive)
    @concealed = schools(:concealed)
  end

  test "listed excludes inactive schools by default" do
    listed = School.listed

    assert_includes listed, @active
    assert_includes listed, @concealed
    assert_not_includes listed, @inactive
  end

  test "listed includes inactive schools when requested" do
    assert_includes School.listed(include_inactive: true), @inactive
  end

  test "deactivating creates a deactivation and conceals the store listing" do
    assert_difference -> { School::Deactivation.count }, 1 do
      @active.deactivate(user: @admin)
    end

    assert @active.deactivated?
    assert @active.store_concealed?
    assert_equal @admin, @active.deactivated_by
  end

  test "activating removes deactivation without revealing the store listing" do
    @inactive.activate
    @inactive.reload

    assert @inactive.active?
    assert @inactive.store_concealed?
  end

  test "concealing an active school hides it in the store" do
    @active.conceal_in_store(user: @admin)

    assert @active.store_concealed?
    assert_equal @admin, @active.store_concealed_by
  end

  test "revealing a concealed active school shows it in the store" do
    @concealed.reveal_in_store
    @concealed.reload

    assert @concealed.store_visible?
  end

  test "revealing an inactive school raises Inactive" do
    assert_raises(StoreConcealable::Inactive) do
      @inactive.reveal_in_store
    end
  end

  test "normalizes blank wix collection id to nil" do
    school = School.new(wix_collection_id: "  ")
    school.valid?
    assert_nil school.wix_collection_id
  end

  test "rejects duplicate wix collection id" do
    school = School.new(wix_collection_id: @active.wix_collection_id)
    assert_not school.valid?
    assert_includes school.errors[:wix_collection_id], "has already been taken"
  end

  test "rejects invalid url" do
    school = School.new(url: "not-a-url")
    assert_not school.valid?
    assert school.errors[:url].any?
  end

  test "deletion is allowed in M1 and destroys the school" do
    deletion = @active.deletion
    assert deletion.allowed?

    assert_difference -> { School.count }, -1 do
      deletion.perform
    end
  end

  test "display_title falls back when title is blank" do
    school = School.create!(title: nil)
    assert_equal "Escola ##{school.id}", school.display_title
  end
end
