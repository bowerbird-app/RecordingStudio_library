# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class PlaceNew < ApplicationService
      def initialize(parent_recording:, type:, library: nil, library_recording: nil, attrs: {}, actor: nil)
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
        resolved_actor = resolve_actor(actor)
        assert_placement_enabled!(parent)
        authorize_placement!(action: :upload, actor: resolved_actor, recording: parent)

        library = require_library!(parent)
        type_name = type_string
        assert_adapter_registered!(type_name)
        assert_library_allows_type!(library, type_name)
        assert_library_key_allowed!(library)
        assert_placeable_type!(parent, type_name)
        RecordingStudioLibrary::Authorization.authorize_library!(
          action: :upload,
          actor: resolved_actor,
          recording: library
        )

        ActiveRecord::Base.transaction do
          item = record_item!(library, resolved_actor)
          result = Place.call(
            parent_recording: parent,
            item_recording: item,
            actor: resolved_actor
          )
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

      def type_string
        name = type.is_a?(Class) ? type.name : type.to_s
        raise ArgumentError, I18n.t("recording_studio.library.errors.type_required") if name.blank?

        name
      end

      def record_item!(library, resolved_actor)
        result = RecordLibraryItem.call(
          library_recording: library,
          type: type,
          attrs: attrs,
          actor: resolved_actor
        )
        raise ArgumentError, result.error if result.failure?

        result.value
      end
    end
  end
end
