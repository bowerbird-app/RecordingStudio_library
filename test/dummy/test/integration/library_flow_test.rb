# frozen_string_literal: true

require "test_helper"

class LibraryFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users_admin
    sign_in @user
    Current.actor = @user
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_admin!(@user, @root)
    @library = RecordingStudioLibrary.library_for(@root, actor: @user)
    @showcase = Showcase.find_or_create_by!(title: "Homepage gallery")
    @showcase_recording = RecordingStudio::Recording.find_by(recordable: @showcase) ||
                          RecordingStudio.record!(
                            action: "created",
                            recordable: @showcase,
                            root_recording: @root,
                            parent_recording: @root,
                            actor: @user
                          ).recording
  end

  teardown do
    Current.actor = nil
  end

  test "library_for is idempotent for a key" do
    again = RecordingStudioLibrary.library_for(@root, actor: @user)

    assert_equal @library.id, again.id
    assert_equal "default", @library.recordable.key
  end

  test "place resolve reorder and remove round trip" do
    item = record_sample("Flow sample")
    placement = RecordingStudioLibrary.place!(@showcase_recording, item, actor: @user)

    resolved = RecordingStudioLibrary.resolve(@showcase_recording, actor: @user)
    assert resolved.any? { |entry| entry.item_recording.id == item.id }

    second = record_sample("Second sample")
    second_placement = RecordingStudioLibrary.place!(@showcase_recording, second, actor: @user)
    RecordingStudioLibrary.reorder!(
      @showcase_recording,
      [second_placement.id, placement.id],
      actor: @user
    )

    ordered = RecordingStudioLibrary.resolve(@showcase_recording, actor: @user).map { |entry| entry.item_recording.id }
    assert_equal [second.id, item.id], ordered.first(2)

    RecordingStudioLibrary.remove!(second_placement, holder: @showcase_recording, actor: @user)
    remaining = RecordingStudioLibrary.resolve(@showcase_recording, actor: @user).map { |entry| entry.placement_recording.id }
    refute_includes remaining, second_placement.id
  end

  test "place refuses a cross-root item" do
    other = Workspace.create!(name: "Other #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other)
    other_library = RecordingStudioLibrary.library_for(other_root, actor: @user)
    foreign = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: "Foreign", accent: "ink"),
      root_recording: other_root,
      parent_recording: other_library,
      actor: @user
    ).recording

    error = assert_raises(ArgumentError) do
      RecordingStudioLibrary.place!(@showcase_recording, foreign, actor: @user)
    end
    assert_match(/another workspace/, error.message)
  end

  test "resolve skips trashed items" do
    item = record_sample("Trashed later")
    RecordingStudioLibrary.place!(@showcase_recording, item, actor: @user)
    item.recording_studio_trashable_trash!(actor: @user)

    resolved = RecordingStudioLibrary.resolve(@showcase_recording, actor: @user)
    refute resolved.any? { |entry| entry.item_recording.id == item.id }

    including = RecordingStudioLibrary.resolve(@showcase_recording, include_trashed: true, actor: @user)
    assert including.any? { |entry| entry.item_recording.id == item.id }
  end

  test "usages warn when an item is placed and delete removes placements" do
    item = record_sample("In use")
    placement = RecordingStudioLibrary.place!(@showcase_recording, item, actor: @user)
    usages = RecordingStudioLibrary.usages(item)

    assert_equal 1, usages.size
    assert_equal @showcase_recording.id, usages.first.parent_recording.id

    item.destroy!
    refute RecordingStudio::Recording.exists?(placement.id)
  end

  test "library page list and grid render through the adapter" do
    record_sample("Grid sample")

    get recording_studio_library.library_path(@library, view: :grid)
    assert_response :success
    assert_select "p", text: /Grid sample/

    get recording_studio_library.library_path(@library, view: :list)
    assert_response :success
    assert_select "p, a, td", text: /Grid sample/
  end

  test "library page omits dummy workspace chrome and labels add by type" do
    get recording_studio_library.library_path(@library)

    assert_response :success
    refute_includes @response.body, "Sign out"
    refute_includes @response.body, "recording-studio-root-switchable--root-switch-dropdown"
    # Button label is type-only ("Sample"); empty-state copy may say "Add samples".
    assert_select "a[href*='sample_items/new']", text: /\A\s*Sample\s*\z/
    assert_select "a[href*='sample_items/new']", text: /Add sample/, count: 0
  end

  test "picker standalone and modal screens render" do
    record_sample("Picker sample")

    get recording_studio_library.recording_picker_path(@showcase_recording)
    assert_response :success
    assert_select "p", text: /Picker sample/
    assert_includes @response.body, "flat-pack-checkbox"
    assert_includes @response.body, "flat-pack--unsaved-changes"
    assert_includes @response.body, "Add selected"
    refute_includes @response.body, "Sign out"
    add_index = @response.body.index("Add selected")
    search_index = @response.body.index('name="q"') || @response.body.index("name='q'")
    assert add_index && search_index && add_index < search_index

    get recording_studio_library.recording_picker_path(@showcase_recording, modal: "1", modal_id: "library-picker")
    assert_response :success
    assert_includes @response.body, "library-picker-screen"
    assert_includes @response.body, "data-fp-nav"
    assert_includes @response.body, "flat-pack--unsaved-changes"
    assert_includes @response.body, "Add selected"
    refute_includes @response.body, "data-fp-screen-footer"
  end

  test "home page still shows dummy workspace chrome" do
    get root_path

    assert_response :success
    assert_includes @response.body, "Sign out"
  end

  test "sample create posts nested fields through the adapter" do
    assert_difference -> { RecordingStudioLibrary::SampleItem.count }, 1 do
      post recording_studio_library.recording_sample_items_path(@library), params: {
        sample_item: { title: "Posted sample", summary: "From the form", accent: "sky" }
      }
    end

    assert_redirected_to recording_studio_library.library_path(@library)
    follow_redirect!
    assert_select "p", text: /Posted sample/
    item = RecordingStudioLibrary::SampleItem.find_by!(title: "Posted sample")
    assert_equal "From the form", item.summary
    assert_equal "sky", item.accent
  end

  test "placements editor renders orderable list" do
    item = record_sample("Placed sample")
    RecordingStudioLibrary.place!(@showcase_recording, item, actor: @user)

    get recording_studio_library.recording_placements_path(@showcase_recording)
    assert_response :success
    assert_select "p", text: /Placed sample/
    assert_includes @response.body, "moving_recording_id"
    assert_includes @response.body, "placements/reorder"
    assert_includes @response.body, "data-modal-id"
  end

  test "home page links to library picker and placements" do
    get root_path
    assert_response :success
    assert_select "h1, h2, p, span, div", text: /Library Demo/
    assert_includes @response.body, "@hotwired/turbo-rails"
  end

  private

  def users_admin
    User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
  end

  def record_sample(title)
    existing = RecordingStudioLibrary::SampleItem.find_by(title: title)
    return RecordingStudio::Recording.find_by!(recordable: existing) if existing

    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: title, summary: "#{title} summary", accent: "coral"),
      root_recording: @root,
      parent_recording: @library,
      actor: @user
    ).recording
  end
end
