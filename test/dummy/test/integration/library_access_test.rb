# frozen_string_literal: true

require "test_helper"

class LibraryAccessTest < ActiveSupport::TestCase
  setup do
    @owner = User.find_or_create_by!(email: "owner-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @stranger = User.find_or_create_by!(email: "stranger-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @workspace = Workspace.create!(name: "Access #{SecureRandom.hex(4)}")
    Current.actor = @owner
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_admin!(@owner, @root)
    @library = RecordingStudioLibrary.library_for(@root, actor: @owner)
    @showcase = Showcase.create!(title: "Private gallery")
    @holder = RecordingStudio.record!(
      action: "created",
      recordable: @showcase,
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
    @item = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: "Hidden still", accent: "ink"),
      root_recording: @root,
      parent_recording: @library,
      actor: @owner
    ).recording
    RecordingStudioLibrary.place!(@holder, @item, actor: @owner)
  end

  teardown do
    Current.actor = nil
  end

  test "resolve hides items the actor cannot see" do
    visible = RecordingStudioLibrary.resolve(@holder, actor: @owner)
    hidden = RecordingStudioLibrary.resolve(@holder, actor: @stranger)

    assert visible.any? { |entry| entry.item_recording.id == @item.id }
    refute hidden.any? { |entry| entry.item_recording.id == @item.id }
  end
end
