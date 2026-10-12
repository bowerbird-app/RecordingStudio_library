# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class FindOrCreateLibrary < ApplicationService
      def initialize(parent_recording: nil, root_recording: nil, key: LibraryQuery::DEFAULT_KEY, actor: nil)
        @parent_recording = parent_recording || root_recording
        @key = LibraryQuery.normalize_key(key)
        @actor = actor
      end

      private

      attr_reader :parent_recording, :key, :actor

      def perform
        require_recording_studio!
        parent = require_parent!
        assert_key_allowed!(parent)
        existing = LibraryQuery.for_parent_and_key(parent, key)
        return success(existing) if existing.present?

        restored = restore_trashed_library(parent)
        return success(restored) if restored.present?

        success(create_library(parent))
      end

      def require_parent!
        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required") if parent_recording.blank?
        return parent_recording if parent_recording.respond_to?(:id) && parent_recording.id.present?

        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required")
      end

      def assert_key_allowed!(parent)
        allowed = LibraryQuery.allowed_keys_for(parent)
        return if allowed.empty? || allowed.include?(key)

        raise ArgumentError, I18n.t("recording_studio.library.errors.key_not_allowed")
      end

      def restore_trashed_library(parent)
        trashed = LibraryQuery.trashed_for_parent_and_key(parent, key)
        return if trashed.blank?
        return unless trashed.respond_to?(:recording_studio_trashable_restore!)

        trashed.recording_studio_trashable_restore!(actor: resolve_actor(actor))
        trashed
      end

      def create_library(parent)
        event = RecordingStudio.record!(
          action: "created",
          recordable: RecordingStudioLibrary::Library.new(key: key),
          root_recording: LibraryQuery.root_for(parent),
          parent_recording: parent,
          actor: resolve_actor(actor),
          idempotency_key: LibraryQuery.idempotency_key(parent, key)
        )
        event.recording
      end
    end
  end
end
