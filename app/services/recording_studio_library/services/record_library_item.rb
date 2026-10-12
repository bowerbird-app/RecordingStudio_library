# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class RecordLibraryItem < ApplicationService
      def initialize(library_recording:, type:, attrs: {}, actor: nil)
        @library_recording = library_recording
        @type = type
        @attrs = attrs.to_h.symbolize_keys
        @actor = actor
      end

      private

      attr_reader :library_recording, :type, :attrs, :actor

      def perform
        require_recording_studio!
        library = require_library!
        resolved_actor = resolve_actor(actor)
        RecordingStudioLibrary::Authorization.authorize_library!(
          action: :upload,
          actor: resolved_actor,
          recording: library
        )
        type_name = type_string
        assert_library_allows_type!(library, type_name)
        assert_library_key_allowed!(library)
        assert_adapter_registered!(type_name)
        klass = item_class

        recordable = klass.new(attrs)
        event = RecordingStudio.record!(
          action: "created",
          recordable: recordable,
          root_recording: LibraryQuery.root_for(library),
          parent_recording: library,
          actor: resolved_actor
        )
        success(event.recording)
      end

      def require_library!
        raise ArgumentError, I18n.t("recording_studio.library.errors.library_required") unless LibraryQuery.live?(library_recording)

        library_recording
      end

      def type_string
        name = type.is_a?(Class) ? type.name : type.to_s
        raise ArgumentError, I18n.t("recording_studio.library.errors.type_required") if name.blank?

        name
      end

      def item_class
        klass = type_string.safe_constantize
        raise ArgumentError, I18n.t("recording_studio.library.errors.type_not_allowed") if klass.blank?

        klass
      end
    end
  end
end
