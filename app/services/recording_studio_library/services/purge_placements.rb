# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class PurgePlacements < ApplicationService
      def initialize(item_recording:)
        @item_recording = item_recording
      end

      private

      attr_reader :item_recording

      def perform
        require_recording_studio!
        return success([]) if item_recording.blank? || Placements.placement_recording?(item_recording)
        return success([]) if Placements.library_recording?(item_recording)

        success(destroy_placements)
      end

      def destroy_placements
        placement_recordings.each(&:destroy!)
      end

      def placement_recordings
        ids = placement_recordable_ids
        return [] if ids.empty?

        scope = RecordingStudio::Recording
        scope = scope.unscoped if scope.respond_to?(:unscoped)
        scope.where(recordable_type: Placements::PLACEMENT_TYPE, recordable_id: ids).to_a
      end

      def placement_recordable_ids
        return [] unless defined?(RecordingStudioLibrary::Placement)

        RecordingStudioLibrary::Placement.where(item_recording_id: item_recording.id).pluck(:id)
      rescue StandardError
        []
      end
    end
  end
end
