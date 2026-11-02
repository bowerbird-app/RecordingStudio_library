# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioLibrary.instance_variable_get(:@configuration)
    RecordingStudioLibrary.instance_variable_set(:@configuration, RecordingStudioLibrary::Configuration.new)
  end

  def teardown
    RecordingStudioLibrary.configuration.hooks.clear!
    RecordingStudioLibrary.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioLibrary.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioLibrary.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_library.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_library.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioLibrary.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_library).new({ library_label: "From x" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { layout: "from_yaml" }
      end
    end.new(app_config)

    find_initializer("recording_studio_library.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudioLibrary.configuration, hook_payload
    assert_equal "from_yaml", RecordingStudioLibrary.configuration.layout
    assert_equal "From x", RecordingStudioLibrary.configuration.library_label
  end

  def test_load_config_handles_errors_and_each_pair_fallback
    pair_config = Class.new do
      def each_pair
        yield(:layout, "from-pair")
      end
    end.new

    xcfg = Struct.new(:recording_studio_library).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)

    app = Struct.new(:config) do
      def config_for(_name)
        raise "Could not load configuration. No such file - recording_studio_library.yml"
      end
    end.new(app_config)

    find_initializer("recording_studio_library.load_config").block.call(app)

    assert_equal "from-pair", RecordingStudioLibrary.configuration.layout
  end

  def test_load_config_raises_when_each_pair_fails
    bad_pair_config = Class.new do
      def each_pair
        raise "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_library).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { layout: "ok" }
      end
    end.new(app_config)

    error = assert_raises(RuntimeError) do
      find_initializer("recording_studio_library.load_config").block.call(app)
    end
    assert_equal "bad pair", error.message
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    find_initializer("recording_studio_library.load_config").block.call(app)

    assert_equal :default, RecordingStudioLibrary.configuration.layout
  end

  def test_load_config_skips_yaml_that_cannot_merge
    yaml = Object.new

    xcfg = Struct.new(:recording_studio_library).new({ layout: "from-x" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      attr_accessor :yaml

      def config_for(_name)
        @yaml
      end
    end.new(app_config)
    app.yaml = yaml

    find_initializer("recording_studio_library.load_config").block.call(app)

    assert_equal "from-x", RecordingStudioLibrary.configuration.layout
  end

  def test_engine_does_not_walk_active_record_or_controller_descendants
    source = File.read(File.expand_path("../lib/recording_studio_library/engine.rb", __dir__))

    refute_includes source, "descendants"
    assert_nil find_initializer("recording_studio_library.apply_model_extensions")
    assert_nil find_initializer("recording_studio_library.apply_controller_extensions")
  end

  def test_purge_hook_registers_on_core_recording_extensions
    RecordingStudioLibrary::Engine.register_recording_studio_integration

    assert RecordingStudio.configuration.hooks.model_extensions_for(:recording).any?
    source = File.read(File.expand_path("../lib/recording_studio_library/engine.rb", __dir__))
    refute_includes source, "Recording.include"
  end

  def test_apply_model_extensions_adds_registered_methods_once
    model_class = Class.new do
      def self.name
        "ExampleRecord"
      end
    end

    RecordingStudioLibrary.configuration.hooks.extend_model(:ExampleRecord) do
      def template_extension_method
        :applied
      end
    end

    RecordingStudioLibrary::Engine.apply_model_extensions(model_class)
    RecordingStudioLibrary::Engine.apply_model_extensions(model_class)

    instance = model_class.new
    assert_equal :applied, instance.template_extension_method
  end

  def test_apply_controller_extensions_matches_demodulized_name
    controller_class = Class.new do
      def self.name
        "Admin::DashboardController"
      end
    end

    RecordingStudioLibrary.configuration.hooks.extend_controller(:DashboardController) do
      def template_controller_extension
        :applied
      end
    end

    RecordingStudioLibrary::Engine.apply_controller_extensions(controller_class)

    instance = controller_class.new
    assert_equal :applied, instance.template_controller_extension
  end

  def test_apply_model_extensions_returns_without_target
    assert_nil RecordingStudioLibrary::Engine.apply_model_extensions(nil)
  end

  private

  def find_initializer(name)
    RecordingStudioLibrary::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
