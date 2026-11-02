# frozen_string_literal: true

module RecordingStudioLibrary
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioLibrary

    class << self
      def apply_model_extensions(target)
        return unless target

        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        return unless target

        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      def register_recording_studio_integration
        return unless defined?(RecordingStudio)

        register_library_capabilities
        register_library_recordable_types
        install_purge_hook
      end

      def register_library_capabilities
        RecordingStudio.register_capability(
          :library,
          recording_methods: RecordingStudio::Capabilities::Library::RecordingMethods,
          source: "recording_studio_library",
          child_recordables: ["RecordingStudioLibrary::Library"]
        )
        RecordingStudio.register_capability(
          :placeable,
          recording_methods: RecordingStudio::Capabilities::Placeable::RecordingMethods,
          source: "recording_studio_library",
          child_recordables: ["RecordingStudioLibrary::Placement"]
        )
      end

      def register_library_recordable_types
        register_recordable_type_if_needed("RecordingStudioLibrary::Library") if capability_parent_types_registered?(:library)
        register_recordable_type_if_needed("RecordingStudioLibrary::Placement") if capability_parent_types_registered?(:placeable)
        register_recordable_type_if_needed("RecordingStudioLibrary::SampleItem")
      end

      def register_recordable_type_if_needed(type_name)
        return if Array(RecordingStudio.configuration.recordable_types).map(&:to_s).include?(type_name)
        return if defined?(RecordingStudio::Recording) && !RecordingStudio::Recording.respond_to?(:delegated_type)
        return unless RecordingStudio.respond_to?(:recordable_declaration_defined?) &&
                      RecordingStudio.recordable_declaration_defined?(type_name)

        RecordingStudio.register_recordable_type(type_name)
      end

      def capability_parent_types_registered?(capability_name)
        configuration = RecordingStudio.configuration
        return false unless configuration.respond_to?(:enabled_recordable_types_for)

        Array(configuration.enabled_recordable_types_for(capability_name)).any?
      end

      def install_purge_hook
        return unless defined?(RecordingStudio)
        return if @library_purge_hook_registered

        RecordingStudio.configuration.hooks.extend_model(:recording) do
          include RecordingStudioLibrary::Purge unless included_modules.include?(RecordingStudioLibrary::Purge)
        end
        @library_purge_hook_registered = true
      end

      def load_yaml_configuration(app)
        app.config_for(:recording_studio_library)
      rescue RuntimeError => e
        raise unless missing_yaml_configuration?(e)

        nil
      end

      def merge_x_configuration(app)
        return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_library)

        xcfg = app.config.x.recording_studio_library
        if xcfg.respond_to?(:to_h)
          RecordingStudioLibrary.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |key, value| hash[key] = value }
          RecordingStudioLibrary.configuration.merge!(hash) if hash.any?
        end
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioLibrary.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_library_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_library_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end

      def missing_yaml_configuration?(error)
        error.message.include?("No such file")
      end
    end

    initializer "recording_studio_library.before_initialize", before: "recording_studio_library.load_config" do |_app|
      RecordingStudioLibrary.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_library.load_config" do |app|
      if app.respond_to?(:config_for)
        yaml = RecordingStudioLibrary::Engine.load_yaml_configuration(app)
        RecordingStudioLibrary.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      RecordingStudioLibrary::Engine.merge_x_configuration(app)

      RecordingStudioLibrary.configuration.hooks.run(:on_configuration, RecordingStudioLibrary.configuration)
    end

    initializer "recording_studio_library.after_initialize", after: "recording_studio_library.load_config" do |_app|
      RecordingStudioLibrary.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_library.register_recording_studio_integration" do |app|
      RecordingStudioLibrary::Engine.register_recording_studio_integration

      app.config.after_initialize do
        RecordingStudioLibrary::Engine.register_recording_studio_integration
      end
    end

    initializer "recording_studio_library.action_view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioLibrary::ApplicationHelper
      end
    end
  end
end
