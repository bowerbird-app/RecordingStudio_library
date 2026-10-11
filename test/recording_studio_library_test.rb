# frozen_string_literal: true

require "test_helper"

class RecordingStudioLibraryTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.1.0", ::RecordingStudioLibrary::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioLibrary::Engine
  end

  def test_gemspec_pins_recording_studio_4_2
    gemspec = File.read(File.expand_path("../recording_studio_library.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, "https://github.com/bowerbird-app/RecordingStudio_library"
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_library.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_root_and_dummy_gemfiles_pin_github_tags
    root = File.read(File.expand_path("../Gemfile", __dir__))
    dummy = File.read(File.expand_path("dummy/Gemfile", __dir__))

    [
      'github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"',
      'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.14.0"',
      'github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.2.8"',
      'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.7.0"',
      'github: "bowerbird-app/flatpack", tag: "v0.1.227"'
    ].each do |pin|
      assert_includes root, pin
      assert_includes dummy, pin
    end
  end

  def test_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_library/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_library/services/base_service.rb", __dir__))
  end

  def test_library_capability_wraps_include_for
    source = File.read(File.expand_path("../lib/recording_studio/capabilities/library.rb", __dir__))

    assert_includes source, "def self.to(**options)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:library, **options)"
    refute_includes source, "enable_capability"
  end

  def test_placeable_capability_wraps_include_for
    source = File.read(File.expand_path("../lib/recording_studio/capabilities/placeable.rb", __dir__))

    assert_includes source, "def self.to(**options)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:placeable, **options)"
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
  end

  def test_dummy_home_page_uses_library_demo_copy
    view_source = File.read(File.expand_path("dummy/app/views/home/index.html.erb", __dir__))

    assert_includes view_source, 'title: "Library Demo"'
    assert_includes view_source, "library_path_for"
    assert_includes view_source, "library_placements_path_for"
    assert_includes view_source, "library_picker_path_for"
    assert_includes view_source, "dummy_page_nav"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_library/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end

  def test_engine_registers_the_dummy_adapter
    assert_includes RecordingStudioLibrary::Adapters.registered_types, "RecordingStudioLibrary::SampleItem"
  end

  def test_placements_view_uses_orderable_helper_and_navigable_modal
    source = File.read(File.expand_path("../app/views/recording_studio_library/placements/index.html.erb", __dir__))

    assert_includes source, "library_reorder_placements_path_for"
    assert_includes source, "navigable: true"
    assert_includes source, "FlatPack::Modal::Component"
    refute_includes source, "reorder_recording_placements_path"
  end

  def test_picker_uses_navigable_modal_screen
    picker = File.read(File.expand_path("../app/views/recording_studio_library/pickers/index.html.erb", __dir__))
    body = File.read(File.expand_path("../app/views/recording_studio_library/pickers/_picker_body.html.erb", __dir__))

    assert_includes picker, "flat_pack_modal_screen"
    assert_includes body, "fp_nav"
    assert_includes body, "item_recording_ids[]"
    assert_includes body, "FlatPack::Checkbox::Component"
    assert_includes body, "FlatPack::Card::Component"
    refute_includes body, "border-(--surface-border-color)"
  end

  def test_engine_screens_use_host_page_nav_helper
    Dir[File.expand_path("../app/views/recording_studio_library/**/*.erb", __dir__)].each do |path|
      source = File.read(path)
      refute_includes source, "FlatPack::PageNav::Component", path
    end

    helper = File.read(File.expand_path("../app/helpers/recording_studio_library/application_helper.rb", __dir__))
    assert_includes helper, "def library_screen_page_nav"
    assert_includes helper, "recording_studio_page_nav"
  end

  def test_find_library_is_find_only
    source = File.read(File.expand_path("../lib/recording_studio_library.rb", __dir__))

    assert_includes source, "def find_library(parent, key: :default)"
    refute_includes source, "alias include_trashed_images"
  end

  def test_place_new_validates_before_recording
    source = File.read(File.expand_path("../app/services/recording_studio_library/services/place_new.rb", __dir__))

    assert_includes source, "assert_adapter_registered!"
    assert_includes source, "assert_library_allows_type!"
    assert_includes source, "authorize_library!"
    assert_includes source, "ActiveRecord::Base.transaction"
    refute_match(/safe_constantize.*\n.*record!/m, source)
  end
end
