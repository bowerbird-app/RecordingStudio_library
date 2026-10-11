# frozen_string_literal: true

require "test_helper"

class LibraryGuardTest < ActiveSupport::TestCase
  setup do
    @user = User.find_or_create_by!(email: "guard-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @workspace = Workspace.create!(name: "Guard #{SecureRandom.hex(4)}")
    Current.actor = @user
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_admin!(@user, @root)
    @library = RecordingStudioLibrary.library_for(@root, actor: @user)
    @showcase = Showcase.create!(title: "Guard gallery")
    @holder = RecordingStudio.record!(
      action: "created",
      recordable: @showcase,
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
  end

  teardown do
    Current.actor = nil
    RecordingStudioLibrary.configuration.unfiltered_access = false
  end

  test "anonymous resolve hides items unless unfiltered_access is on" do
    item = record_sample("Anonymous still")
    RecordingStudioLibrary.place!(@holder, item, actor: @user)

    hidden = RecordingStudioLibrary.resolve(@holder, actor: nil)
    refute hidden.any? { |entry| entry.item_recording.id == item.id }

    RecordingStudioLibrary.configuration.unfiltered_access = true
    visible = RecordingStudioLibrary.resolve(@holder, actor: nil)
    assert visible.any? { |entry| entry.item_recording.id == item.id }
  end

  test "place refuses an item Accessible hides from the actor" do
    item = record_sample("Hidden from editor")
    RecordingStudioLibrary::Authorization.stub(:visible?, false) do
      error = assert_raises(ArgumentError) do
        RecordingStudioLibrary.place!(@holder, item, actor: @user)
      end
      assert_match(/cannot place that item/, error.message)
    end
  end

  test "library type allow-list is enforced when recording into a library" do
    RecordingStudioLibrary.register_adapter("Folder", RecordingStudioLibrary::Adapters::Dummy)
    folder = Folder.create!(name: "Not a sample #{SecureRandom.hex(4)}")
    result = RecordingStudioLibrary::Services::RecordLibraryItem.call(
      library_recording: @library,
      type: "Folder",
      attrs: { name: folder.name },
      actor: @user
    )

    assert result.failure?
    assert_match(/cannot be placed/, result.error)
  ensure
    RecordingStudioLibrary::Adapters.registry.delete("Folder")
  end

  test "library key allow-list is enforced when recording into a library" do
    logos = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::Library.new(key: "logos"),
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording

    result = RecordingStudioLibrary::Services::RecordLibraryItem.call(
      library_recording: logos,
      type: "RecordingStudioLibrary::SampleItem",
      attrs: { title: "Logo mark", accent: "ink" },
      actor: @user
    )

    assert result.failure?
    assert_match(/not available/, result.error)
  end

  test "library_for refuses a key the parent does not allow" do
    error = assert_raises(ArgumentError) do
      RecordingStudioLibrary.library_for(@root, key: :logos, actor: @user)
    end
    assert_match(/not available/, error.message)
  end

  test "place refuses a holder type that is not on Placeable.to" do
    folder = Folder.create!(name: "Stage folder #{SecureRandom.hex(4)}")
    folder_recording = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording

    error = assert_raises(ArgumentError) do
      RecordingStudioLibrary.place!(@holder, folder_recording, actor: @user)
    end
    assert_match(/cannot be placed/, error.message)
  end

  test "place_new refuses an unregistered type and does not leave an item behind" do
    assert_no_difference -> { RecordingStudioLibrary::SampleItem.count } do
      error = assert_raises(ArgumentError) do
        RecordingStudioLibrary.place_new!(
          @holder,
          library: @library,
          type: "Unknown::Thing",
          attrs: { title: "Nope" },
          actor: @user
        )
      end
      assert_match(/not set up/, error.message)
    end
  end

  test "place_new rolls back the recorded item when place fails" do
    failure = Struct.new(:failure?, :error, :success?, keyword_init: true).new(
      failure?: true,
      success?: false,
      error: "forced"
    )

    assert_no_difference -> { RecordingStudioLibrary::SampleItem.count } do
      RecordingStudioLibrary::Services::Place.stub(:call, failure) do
        result = RecordingStudioLibrary::Services::PlaceNew.call(
          parent_recording: @holder,
          library: @library,
          type: "RecordingStudioLibrary::SampleItem",
          attrs: { title: "Rolled back #{SecureRandom.hex(4)}", accent: "ink" },
          actor: @user
        )
        assert result.failure?
        assert_equal "forced", result.error
      end
    end
  end

  test "reorder refuses another holders placement id" do
    item = record_sample("Owned still")
    other_showcase = Showcase.create!(title: "Other gallery")
    other_holder = RecordingStudio.record!(
      action: "created",
      recordable: other_showcase,
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
    foreign = RecordingStudioLibrary.place!(other_holder, item, actor: @user)
    owned = RecordingStudioLibrary.place!(@holder, item, actor: @user)

    error = assert_raises(ArgumentError) do
      RecordingStudioLibrary.reorder!(
        @holder,
        actor: @user,
        moving_recording_id: foreign.id,
        target_position: 1
      )
    end
    assert_match(/not on this page/, error.message)
    assert RecordingStudio::Recording.exists?(owned.id)
    assert_equal other_holder.id, foreign.parent_recording_id
  end

  private

  def record_sample(title)
    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: title, summary: "#{title} summary", accent: "coral"),
      root_recording: @root,
      parent_recording: @library,
      actor: @user
    ).recording
  end
end
