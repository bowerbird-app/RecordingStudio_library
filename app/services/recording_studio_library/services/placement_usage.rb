# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class PlacementUsage < ApplicationService
      def initialize(item_recording:)
        @item_recording = item_recording
      end

      private

      attr_reader :item_recording

      def perform
        require_recording_studio!
        return success([]) if item_recording.blank? || Placements.placement_recording?(item_recording)

        success(usages)
      end

      def usages
        placement_recordings.filter_map do |placement|
          next if placement.try(:trashed_at).present?

          parent = placement.try(:parent_recording)
          next if parent.blank?

          Placements::Usage.new(
            placement_recording: placement,
            parent_recording: parent,
            label: Placements.place_label(parent)
          )
        end
      end

      def placement_recordings
        ids = placement_recordable_ids
        return [] if ids.empty?

        relation = RecordingStudio::Recording.where(
          recordable_type: Placements::PLACEMENT_TYPE,
          recordable_id: ids
        )
        relation = relation.includes(:recordable, :parent_recording) if relation.respond_to?(:includes)
        relation.order(:created_at, :id).to_a
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
