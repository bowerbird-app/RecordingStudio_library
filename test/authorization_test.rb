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

  def test_visible_delegates_to_accessible
    recording = Recording.new(recordable_type: "Workspace")
    seen = nil

    RecordingStudioAccessible.stub :authorized?, lambda { |**kwargs|
      seen = kwargs
      true
    } do
      assert RecordingStudioLibrary::Authorization.visible?(actor: :user, recording: recording)
    end

    assert_equal({ actor: :user, recording: recording, role: :view }, seen)
  end

  def test_visible_is_closed_when_accessible_is_missing
    recording = Recording.new(recordable_type: "Workspace")

    RecordingStudioAccessible.stub :respond_to?, false do
      refute RecordingStudioLibrary::Authorization.visible?(actor: :user, recording: recording)
    end
  end

  def test_library_allowed_delegates_to_accessible
    recording = Recording.new(recordable_type: "Workspace")
    seen = nil

    RecordingStudio.stub :capability_enabled?, true do
      RecordingStudioAccessible.stub :authorized?, lambda { |**kwargs|
        seen = kwargs
        true
      } do
        assert RecordingStudioLibrary::Authorization.library_allowed?(
          action: :upload,
          actor: :user,
          recording: recording
        )
      end
    end

    assert_equal({ actor: :user, recording: recording, role: :edit }, seen)
  end

  def test_library_allowed_ignores_host_authorizer_and_fails_closed
    recording = Recording.new(recordable_type: "Workspace")

    RecordingStudio.stub :capability_enabled?, true do
      RecordingStudioAccessible.stub :respond_to?, false do
        refute RecordingStudioLibrary::Authorization.library_allowed?(
          action: :upload,
          actor: :user,
          recording: recording
        )
      end
    end
  end
end
