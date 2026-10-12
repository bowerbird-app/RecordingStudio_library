# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  Recording = Struct.new(:id, :recordable_type, keyword_init: true)

  def setup
    @original_unfiltered = RecordingStudioLibrary.configuration.unfiltered_access
    @original_adapter = RecordingStudioLibrary.configuration.authorize_with
    RecordingStudioLibrary.configuration.unfiltered_access = false
    RecordingStudioLibrary.configuration.authorize_with = nil
  end

  def teardown
    RecordingStudioLibrary.configuration.unfiltered_access = @original_unfiltered
    RecordingStudioLibrary.configuration.authorize_with = @original_adapter
  end

  def test_visible_fails_closed_when_accessible_is_not_loaded
    refute defined?(RecordingStudioAccessible::Authorization), "gem tests must exercise the no-Accessible path"
    recording = Recording.new(id: "item-1", recordable_type: "RecordingStudioLibrary::SampleItem")

    refute RecordingStudioLibrary::Authorization.visible?(actor: :ada, recording: recording)
  end

  def test_visible_honors_unfiltered_without_accessible
    refute defined?(RecordingStudioAccessible::Authorization)
    recording = Recording.new(id: "item-1", recordable_type: "RecordingStudioLibrary::SampleItem")

    assert RecordingStudioLibrary::Authorization.visible?(actor: nil, recording: recording, unfiltered: true)
  end

  def test_visible_uses_authorize_adapter_when_accessible_is_missing
    refute defined?(RecordingStudioAccessible::Authorization)
    recording = Recording.new(id: "item-1", recordable_type: "RecordingStudioLibrary::SampleItem")
    seen = nil
    RecordingStudioLibrary.configuration.authorize_with = lambda { |action:, actor:, recording:, role:|
      seen = [action, actor, recording.id, role]
      false
    }

    refute RecordingStudioLibrary::Authorization.visible?(actor: :ada, recording: recording)
    assert_equal [:view, :ada, "item-1", :view], seen
  end

  def test_allowed_fails_closed_when_accessible_is_not_loaded
    refute defined?(RecordingStudioAccessible::Authorization)
    recording = Recording.new(id: "gallery-1", recordable_type: "Showcase")

    RecordingStudioLibrary::Authorization.stub(:placement_enabled?, true) do
      refute RecordingStudioLibrary::Authorization.placement_allowed?(
        action: :upload,
        actor: :ada,
        recording: recording
      )
    end
  end

  def test_allowed_uses_authorize_adapter_when_accessible_is_missing
    refute defined?(RecordingStudioAccessible::Authorization)
    recording = Recording.new(id: "gallery-1", recordable_type: "Showcase")
    RecordingStudioLibrary.configuration.authorize_with = ->(**) { true }

    RecordingStudioLibrary::Authorization.stub(:placement_enabled?, true) do
      assert RecordingStudioLibrary::Authorization.placement_allowed?(
        action: :upload,
        actor: :ada,
        recording: recording
      )
    end
  end
end
