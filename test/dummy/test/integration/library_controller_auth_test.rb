# frozen_string_literal: true

require "test_helper"

class LibraryControllerAuthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.find_or_create_by!(email: "owner-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @viewer = User.find_or_create_by!(email: "viewer-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @stranger = User.find_or_create_by!(email: "stranger-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @workspace = Workspace.create!(name: "Auth #{SecureRandom.hex(4)}")
    Current.actor = @owner
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_admin!(@owner, @root)
    grant_role!(@viewer, @root, :view, manager: @owner)
    @library = RecordingStudioLibrary.library_for(@root, actor: @owner)
    @showcase = Showcase.create!(title: "Auth gallery")
    @holder = RecordingStudio.record!(
      action: "created",
      recordable: @showcase,
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
    @item = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: "Auth still", accent: "ink"),
      root_recording: @root,
      parent_recording: @library,
      actor: @owner
    ).recording
    @placement = RecordingStudioLibrary.place!(@holder, @item, actor: @owner)
  end

  teardown do
    Current.actor = nil
  end

  test "unauthorized create is refused" do
    sign_in @stranger
    Current.actor = @stranger

    assert_no_difference -> { placement_count } do
      post recording_studio_library.recording_placements_path(@holder), params: {
        item_recording_ids: [@item.id]
      }
    end
    assert_response :redirect
    assert flash[:alert].present?
  end

  test "viewer cannot create a placement" do
    sign_in @viewer
    Current.actor = @viewer

    assert_no_difference -> { placement_count } do
      post recording_studio_library.recording_placements_path(@holder), params: {
        item_recording_ids: [@item.id]
      }
    end
    assert_response :redirect
    assert flash[:alert].present?
  end

  test "forged item ids are refused without raising" do
    sign_in @owner
    Current.actor = @owner

    assert_no_difference -> { placement_count } do
      post recording_studio_library.recording_placements_path(@holder), params: {
        item_recording_ids: ["00000000-0000-0000-0000-000000000000"]
      }
    end
    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert_equal I18n.t("recording_studio.library.errors.not_found"), flash[:alert]
  end

  test "unauthorized reorder is refused" do
    sign_in @stranger
    Current.actor = @stranger

    patch recording_studio_library.recording_reorder_placements_path(@holder), params: {
      moving_recording_id: @placement.id,
      target_position: 1
    }
    assert_response :redirect
    assert flash[:alert].present?
  end

  test "viewer cannot reorder" do
    sign_in @viewer
    Current.actor = @viewer

    patch recording_studio_library.recording_reorder_placements_path(@holder), params: {
      moving_recording_id: @placement.id,
      target_position: 1
    }
    assert_response :redirect
    assert flash[:alert].present?
  end

  test "unauthorized remove is refused" do
    sign_in @stranger
    Current.actor = @stranger

    assert_no_difference -> { placement_count } do
      delete recording_studio_library.destroy_placement_path(@placement)
    end
    assert_response :redirect
    assert flash[:alert].present?
    assert RecordingStudio::Recording.exists?(@placement.id)
  end

  test "GET library does not create a missing library" do
    sign_in @owner
    Current.actor = @owner
    empty = Workspace.create!(name: "Empty #{SecureRandom.hex(4)}")
    empty_root = RecordingStudio.root_recording_for(empty)
    grant_admin!(@owner, empty_root)

    assert_no_difference -> { RecordingStudioLibrary::Library.count } do
      get recording_studio_library.recording_library_path(empty_root)
    end
    assert_redirected_to root_path
    assert_equal I18n.t("recording_studio.library.errors.not_found"), flash[:alert]
  end

  test "library page uses a single host page nav" do
    sign_in @owner
    Current.actor = @owner

    get recording_studio_library.library_path(@library)

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_select "nav, [class*='page-nav']"
    refute_match(/Return to source page/, @response.body)
  end

  private

  def placement_count
    RecordingStudio::Recording.where(recordable_type: "RecordingStudioLibrary::Placement").count
  end
end
