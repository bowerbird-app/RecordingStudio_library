# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  def test_register_has_one_api_availability_check
    source = File.read(File.expand_path("../lib/recording_studio_library/api.rb", __dir__))

    assert_equal 1, source.scan("defined?(::RecordingStudioApi)").size
    assert_includes source, "each_api"
    refute_includes source, "const_set"
    refute_includes source, "remove_const"
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioLibrary::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_library.api"
  end

  def test_actions_check_capability_action_before_registering
    actions = File.read(File.expand_path("../lib/recording_studio_library/api/actions.rb", __dir__))
    library = File.read(File.expand_path("../lib/recording_studio_library/api/library_handlers.rb", __dir__))
    placements = File.read(File.expand_path("../lib/recording_studio_library/api/placement_handlers.rb", __dir__))

    assert_includes actions, "capability_action(name, api:)"
    assert_includes placements, "RecordingStudioLibrary.place!"
    assert_includes placements, "RecordingStudioLibrary.place_new!"
    assert_includes placements, "RecordingStudioLibrary.reorder!"
    assert_includes placements, "RecordingStudioLibrary.remove!"
    assert_includes library, "RecordingStudioLibrary.library_for"
    assert_includes library, "RecordingStudioLibrary.find_library"
    assert_includes library, "RecordingStudioLibrary.libraries_for"
    assert_includes placements, "RecordingStudioLibrary.resolve"
    [actions, library, placements].each do |source|
      refute_includes source, "const_set"
      refute_includes source, "remove_const"
    end
  end

  def test_does_not_register_library_or_placement_crud
    Dir[File.expand_path("../lib/recording_studio_library/api/**/*.rb", __dir__)].each do |path|
      source = File.read(path)
      refute_includes source, "register_recordable_type_api", path
      refute_includes source, "register_resource_handler", path
    end
  end
end
