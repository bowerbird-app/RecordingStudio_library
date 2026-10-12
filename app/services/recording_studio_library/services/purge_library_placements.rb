# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class PurgeLibraryPlacements < ApplicationService
      def initialize(library_recording:)
        @library_recording = library_recording
      end

      private

      attr_reader :library_recording

      def perform
        require_recording_studio!
        return success([]) unless Placements.library_recording?(library_recording)

        removed = item_recordings.flat_map do |item|
          PurgePlacements.call(item_recording: item).value || []
        end
        success(removed)
      end

      def item_recordings
        scope = RecordingStudio::Recording
        scope = scope.unscoped if scope.respond_to?(:unscoped)
        scope.where(parent_recording_id: library_recording.id).to_a
      rescue StandardError
        []
      end
    end
  end
end
