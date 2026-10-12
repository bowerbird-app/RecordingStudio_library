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
    assert_response :redirect
    assert_equal "/", URI.parse(@response.redirect_url).path
    assert_equal I18n.t("recording_studio.library.errors.not_found"), flash[:alert]
  end

  test "editor cannot place a hidden item they cannot view" do
    editor = User.find_or_create_by!(email: "item-editor-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    grant_role!(editor, @holder, :edit, manager: @owner)
    visible = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: "Visible still", accent: "sage"),
      root_recording: @root,
      parent_recording: @library,
      actor: @owner
    ).recording
    hidden = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: "Hidden still", accent: "ink"),
      root_recording: @root,
      parent_recording: @library,
      actor: @owner
    ).recording
    grant_role!(editor, visible, :view, manager: @owner)

    sign_in editor
    Current.actor = editor

    assert RecordingStudioLibrary::Authorization.visible?(actor: editor, recording: visible)
    refute RecordingStudioLibrary::Authorization.visible?(actor: editor, recording: hidden)
    assert RecordingStudioLibrary::Authorization.placement_allowed?(
      action: :upload,
      actor: editor,
      recording: @holder
    )

    assert_no_difference -> { placement_count } do
      post recording_studio_library.recording_placements_path(@holder), params: {
        item_recording_ids: [hidden.id]
      }
    end
    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert_equal I18n.t("recording_studio.library.errors.item_not_visible"), flash[:alert]

    assert_difference -> { placement_count }, 1 do
      post recording_studio_library.recording_placements_path(@holder), params: {
        item_recording_ids: [visible.id]
      }
    end
    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert_equal I18n.t("recording_studio.library.flashes.added"), flash[:notice]
  end

  test "current_library_actor falls through a nil Current.actor to current_user" do
    sign_in @owner

    with_replaced_singleton(Current, :actor, -> { nil }) do
      get recording_studio_library.library_path(@library)
      assert_response :success
      assert_select "p, a, td, h1", text: /Library/
    end
  end

  test "library page uses a single host page nav" do
    sign_in @owner
    Current.actor = @owner

    get recording_studio_library.library_path(@library)

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_includes @response.body, "flat_pack/application"
    assert_select "nav, [class*='page-nav']"
    refute_match(/Return to source page/, @response.body)
    refute_includes @response.body, "Sign out"
    refute_includes @response.body, "recording-studio-root-switchable--root-switch-dropdown"
  end

  test "library page falls back to engine page nav when the host has none" do
    sign_in @owner
    Current.actor = @owner

    with_replaced_instance_method(RecordingStudioLibrary::ApplicationHelper, :library_host_page_nav_available?, -> { false }) do
      get recording_studio_library.library_path(@library)

      assert_response :success
      assert_match(/Return to source page/, @response.body)
    end
  end

  test "viewer cannot patch placements without holder revise" do
    sign_in @viewer
    Current.actor = @viewer

    patch recording_studio_library.recording_placements_path(@holder), params: {
      items: { @item.id => { title: "Hacked still" } }
    }

    assert_response :redirect
    assert flash[:alert].present?
    @item.reload
    assert_equal "Auth still", @item.recordable.title
  end

  test "patch refuses an item that is not placed on the holder" do
    other = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: "Unplaced still", accent: "sage"),
      root_recording: @root,
      parent_recording: @library,
      actor: @owner
    ).recording
    sign_in @owner
    Current.actor = @owner

    patch recording_studio_library.recording_placements_path(@holder), params: {
      items: { other.id => { title: "Stolen still" } }
    }

    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert_equal I18n.t("recording_studio.library.errors.placement_not_on_page"), flash[:alert]
    other.reload
    assert_equal "Unplaced still", other.recordable.title
  end

  test "patch refuses another holders placement in ordered ids" do
    other_showcase = Showcase.create!(title: "Other auth gallery")
    other_holder = RecordingStudio.record!(
      action: "created",
      recordable: other_showcase,
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
    foreign = RecordingStudioLibrary.place!(other_holder, @item, actor: @owner)
    sign_in @owner
    Current.actor = @owner

    patch recording_studio_library.recording_placements_path(@holder), params: {
      items: { @item.id => { title: "Renamed still" } },
      ordered_recording_ids: [foreign.id, @placement.id]
    }

    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert_equal I18n.t("recording_studio.library.errors.placement_not_on_page"), flash[:alert]
    @item.reload
    assert_equal "Auth still", @item.recordable.title
  end

  test "patch drops non-permitted item keys" do
    sign_in @owner
    Current.actor = @owner

    patch recording_studio_library.recording_placements_path(@holder), params: {
      items: { @item.id => { title: "Permitted still", extra: "ignored", id: "forged" } }
    }

    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert_equal I18n.t("recording_studio.library.flashes.updated"), flash[:notice]
    @item.reload
    assert_equal "Permitted still", @item.recordable.title
    refute_equal "forged", @item.recordable.id.to_s
  end

  test "editor cannot patch a library item without library revise" do
    editor = User.find_or_create_by!(email: "page-editor-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    grant_role!(editor, @holder, :edit, manager: @owner)
    grant_role!(editor, @item, :view, manager: @owner)
    grant_role!(editor, @library, :view, manager: @owner)

    sign_in editor
    Current.actor = editor

    assert RecordingStudioLibrary::Authorization.placement_allowed?(
      action: :revise,
      actor: editor,
      recording: @holder
    )
    refute RecordingStudioLibrary::Authorization.library_allowed?(
      action: :revise,
      actor: editor,
      recording: @library
    )

    patch recording_studio_library.recording_placements_path(@holder), params: {
      items: { @item.id => { title: "Hacked still" } }
    }

    assert_redirected_to recording_studio_library.recording_placements_path(@holder)
    assert flash[:alert].present?
    @item.reload
    assert_equal "Auth still", @item.recordable.title
  end

  private

  def placement_count
    RecordingStudio::Recording.where(recordable_type: "RecordingStudioLibrary::Placement").count
  end
end
