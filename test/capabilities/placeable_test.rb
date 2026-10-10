# frozen_string_literal: true

require "test_helper"

class PlaceableCapabilityTest < Minitest::Test
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
    source = File.read(File.expand_path("../../lib/recording_studio/capabilities/placeable.rb", __dir__))

    assert_includes source, "def self.to(**options)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:placeable, **options)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
    assert_equal [:to], RecordingStudio::Capabilities::Placeable.singleton_methods(false)
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
      result = RecordingStudio::Capabilities::Placeable.to(types: ["Page"], libraries: [:default])

      assert_same factory, result
    end

    assert_equal :placeable, captured_name
    assert_equal({ types: ["Page"], libraries: [:default] }, captured_options)
  end

  def test_including_to_enables_via_include_for_and_sets_options
    Probe::HostType.include(RecordingStudio::Capabilities::Placeable.to(types: ["Page"], libraries: [:default]))

    assert RecordingStudio.capability_enabled?(:placeable, for: Probe::HostType)
    assert_equal({ types: ["Page"], libraries: [:default] },
                 RecordingStudio.capability_options(:placeable, for: Probe::HostType))
    refute RecordingStudio.capability_enabled?(:placeable, for: Probe::OtherType)
  end
end
