# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class LibraryUsage < ApplicationService
      def initialize(library_recording:)
        @library_recording = library_recording
      end

      private

      attr_reader :library_recording

      def perform
        require_recording_studio!
        return success([]) unless Placements.library_recording?(library_recording)

        success(unique_usages)
      end

      def unique_usages
        usages.uniq { |usage| usage.parent_recording.try(:id) || usage.placement_recording.try(:id) }
      end

      def usages
        item_recordings.flat_map do |item|
          PlacementUsage.call(item_recording: item).value || []
        end
      end

      def item_recordings
        relation = RecordingStudio::Recording.where(parent_recording_id: library_recording.id)
        relation = relation.includes(:recordable) if relation.respond_to?(:includes)
        relation.to_a.reject { |recording| Placements.placement_recording?(recording) }
      rescue StandardError
        []
      end
    end
  end
end
