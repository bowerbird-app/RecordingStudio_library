# frozen_string_literal: true

require "test_helper"

class LibraryCapabilityTest < Minitest::Test
  module Probe
    HostType = Class.new
    OtherType = Class.new
  end

  def setup
    @original_capabilities =
      RecordingStudio.configuration.instance_variable_get(:@capabilities).transform_values(&:dup)
    @original_capability_options =
      RecordingStudio.configuration.instance_variable_get(:@capability_options).dup
    RecordingStudio.configuration.instance_variable_set(:@capabilities, {})
    RecordingStudio.configuration.instance_variable_set(:@capability_options, {})
  end

  def teardown
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def test_to_is_the_include_for_wrapper_not_a_fourth_verb
    source = File.read(File.expand_path("../../lib/recording_studio/capabilities/library.rb", __dir__))

    assert_includes source, "def self.to(**options)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:library, **options)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
    assert_equal [:to], RecordingStudio::Capabilities::Library.singleton_methods(false)
  end

  def test_to_delegates_to_include_for
    captured_name = nil
    captured_options = nil
    factory = Module.new

    RecordingStudio::Capabilities.stub :include_for, lambda { |name, **options|
      captured_name = name
      captured_options = options
      factory
    } do
      result = RecordingStudio::Capabilities::Library.to(types: ["Page"], keys: [:default])

      assert_same factory, result
    end

    assert_equal :library, captured_name
    assert_equal({ types: ["Page"], keys: [:default] }, captured_options)
  end

  def test_to_does_not_enable_until_included
    mixin = RecordingStudio::Capabilities::Library.to(types: ["Page"], keys: [:default])

    assert_kind_of Module, mixin
    refute RecordingStudio.capability_enabled?(:library, for: Probe::HostType)
    assert_nil RecordingStudio.capability_options(:library, for: Probe::HostType)
    assert_empty RecordingStudio.configuration.enabled_recordable_types_for(:library)
  end

  def test_including_to_enables_via_include_for_and_sets_options
    Probe::HostType.include(RecordingStudio::Capabilities::Library.to(types: ["Page"], keys: %i[default logos]))

    assert RecordingStudio.capability_enabled?(:library, for: Probe::HostType)
    assert_equal({ types: ["Page"], keys: %i[default logos] },
                 RecordingStudio.capability_options(:library, for: Probe::HostType))
    refute RecordingStudio.capability_enabled?(:library, for: Probe::OtherType)
    assert_equal [Probe::HostType.name],
                 RecordingStudio.configuration.enabled_recordable_types_for(:library)
  end
end
