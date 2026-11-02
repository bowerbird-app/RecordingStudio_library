# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  Recording = Struct.new(:recordable_type, :parent_recording, keyword_init: true)

  def test_library_enabled_uses_public_capability_for_keyword
    recording = Recording.new(recordable_type: "Workspace")
    seen = nil

    RecordingStudio.stub :capability_enabled?, lambda { |name, **kwargs|
      seen = [name, kwargs]
      true
    } do
      assert RecordingStudioLibrary::Authorization.library_enabled?(recording: recording)
    end

    assert_equal [:library, { for: "Workspace" }], seen
  end

  def test_visible_is_closed_when_accessible_is_missing
    return if defined?(RecordingStudioAccessible::Authorization)

    refute RecordingStudioLibrary::Authorization.visible?(
      actor: nil,
      recording: Recording.new(recordable_type: "Workspace")
    )
  end
end
