# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class LibraryItems < ApplicationService
      def initialize(library_recording:, query: nil, type: nil, actor: nil, include_trashed: false)
        @library_recording = library_recording
        @query = query.to_s.strip
        @type = type.to_s.strip.presence
        @actor = actor
        @include_trashed = include_trashed
      end

      private

      attr_reader :library_recording, :query, :type, :actor, :include_trashed

      def perform
        require_recording_studio!
        return success([]) unless LibraryQuery.live?(library_recording)

        success(filtered)
      end

      def filtered
        items.filter_map do |recording|
          next if recording.try(:trashed_at).present? && !include_trashed
          next unless visible?(recording)
          next if type.present? && recording.recordable_type != type

          adapter = RecordingStudioLibrary.adapter_for(recording)
          next unless adapter.matches?(query)

          [recording, adapter]
        end
      end

      def items
        relation = RecordingStudio::Recording.where(parent_recording_id: library_recording.id)
        relation = relation.includes(:recordable) if relation.respond_to?(:includes)
        relation = relation.order(:created_at, :id) if relation.respond_to?(:order)
        Array(relation).reject { |recording| Placements.placement_recording?(recording) }
      rescue StandardError
        []
      end

      def visible?(recording)
        return true if actor.nil?

        RecordingStudioLibrary::Authorization.visible?(actor: actor, recording: recording)
      end
    end
  end
end
