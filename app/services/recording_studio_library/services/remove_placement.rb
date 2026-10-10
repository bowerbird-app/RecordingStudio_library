# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class RemovePlacement < ApplicationService
      def initialize(parent_recording:, placement_recording:, actor: nil, impersonator: nil)
        @parent_recording = parent_recording
        @placement_recording = placement_recording
        @actor = actor
        @impersonator = impersonator
      end

      private

      attr_reader :parent_recording, :placement_recording, :actor, :impersonator

      def perform
        require_recording_studio!
        parent = require_parent!
        placement = require_placement!(parent)
        assert_placement_enabled!(parent)
        authorize_placement!(action: :remove, actor: resolve_actor(actor), recording: parent)

        if placement.respond_to?(:recording_studio_trashable_trash!)
          placement.recording_studio_trashable_trash!(
            actor: resolve_actor(actor),
            impersonator: impersonator
          )
        else
          placement.destroy!
        end

        success(placement)
      end

      def require_parent!
        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required") if parent_recording.blank?

        parent_recording
      end

      def require_placement!(parent)
        missing = placement_recording.blank?
        wrong_type = !Placements.placement_recording?(placement_recording)
        wrong_parent = placement_recording&.parent_recording_id.to_s != parent.id.to_s
        deny!(:placement_not_on_page) if missing || wrong_type || wrong_parent

        placement_recording
      end
    end
  end
end
