# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class PlaceNew < ApplicationService
      def initialize(parent_recording:, library:, type:, library_recording: nil, attrs: {}, actor: nil)
        @parent_recording = parent_recording
        @library_recording = library_recording.presence || library
        @type = type
        @attrs = attrs.to_h.symbolize_keys
        @actor = actor
      end

      private

      attr_reader :parent_recording, :library_recording, :type, :attrs, :actor

      def perform
        require_recording_studio!
        parent = require_parent!
        assert_placement_enabled!(parent)
        authorize_placement!(action: :upload, actor: resolve_actor(actor), recording: parent)

        library = require_library!(parent)
        item = record_item!(library)
        Place.call(
          parent_recording: parent,
          item_recording: item,
          actor: resolve_actor(actor)
        ).then do |result|
          raise ArgumentError, result.error if result.failure?

          success(result.value)
        end
      end

      def require_parent!
        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required") if parent_recording.blank?

        parent_recording
      end

      def require_library!(parent)
        library = library_recording
        raise ArgumentError, I18n.t("recording_studio.library.errors.library_required") unless LibraryQuery.live?(library)
        raise ArgumentError, I18n.t("recording_studio.library.errors.different_workspace") unless same_root?(parent, library)

        library
      end

      def record_item!(library)
        klass = item_class
        recordable = klass.new(attrs)
        event = RecordingStudio.record!(
          action: "created",
          recordable: recordable,
          root_recording: LibraryQuery.root_for(library),
          parent_recording: library,
          actor: resolve_actor(actor)
        )
        event.recording
      end

      def item_class
        name = type.is_a?(Class) ? type.name : type.to_s
        raise ArgumentError, I18n.t("recording_studio.library.errors.type_required") if name.blank?

        klass = name.safe_constantize
        raise ArgumentError, I18n.t("recording_studio.library.errors.type_not_allowed") if klass.blank?

        klass
      end
    end
  end
end
