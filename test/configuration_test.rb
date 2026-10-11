# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioLibrary::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(layout: "host", library_label: "Library")

    assert_equal "host", @configuration.layout
    assert_equal "Library", @configuration.library_label
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", layout: "custom")

    refute_respond_to @configuration, :unknown_key
    assert_equal "custom", @configuration.layout
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:layout], @configuration.layout
  end

  def test_initialize_uses_defaults
    configuration = RecordingStudioLibrary::Configuration.new

    assert_equal :default, configuration.layout
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
    assert_equal :view, configuration.auth_roles[:view]
    assert_equal :edit, configuration.auth_roles[:upload]
    assert_equal false, configuration.unfiltered_access
    refute_respond_to configuration, :impersonator
    refute_respond_to configuration, :include_trashed_images
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("layout" => "string-key")

    assert_equal "string-key", @configuration.layout
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioLibrary.configure

    assert_kind_of RecordingStudioLibrary::Configuration, RecordingStudioLibrary.configuration
  end

  def test_normalize_role_aliases
    assert_equal :view, @configuration.normalize_role(:viewer)
    assert_equal :edit, @configuration.normalize_role("editor")
  end
end
