# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class ResolvePlacements < ApplicationService
      def initialize(parent_recording:, include_trashed: false, actor: nil, unfiltered: false)
        @parent_recording = parent_recording
        @include_trashed = include_trashed
        @actor = actor
        @unfiltered = unfiltered
      end

      private

      attr_reader :parent_recording, :include_trashed, :actor, :unfiltered

      def perform
        require_recording_studio!
        return success([]) if parent_recording.blank?

        success(resolved_items)
      end

      def resolved_items
        placement_children.filter_map do |child|
          next if hidden_placement?(child)

          item_recording = item_for(child)
          next unless usable_item?(item_recording)

          Placements::Resolved.new(
            placement_recording: child,
            item_recording: item_recording,
            item: item_recording.recordable,
            adapter: RecordingStudioLibrary.adapter_for(item_recording)
          )
        end
      end

      def placement_children
        if parent_recording.respond_to?(:recording_studio_orderable_children)
          Array(parent_recording.recording_studio_orderable_children)
        else
          children_relation.to_a
        end
      end

      def children_relation
        relation = parent_recording.child_recordings.where(recordable_type: Placements::PLACEMENT_TYPE)
        relation = relation.includes(:recordable) if relation.respond_to?(:includes)
        if relation.respond_to?(:order)
          relation.order(:created_at, :id)
        else
          relation
        end
      end

      def hidden_placement?(child)
        child.try(:trashed_at).present? || !Placements.placement_recording?(child)
      end

      def item_for(child)
        id = child.recordable.try(:item_recording_id)
        return if id.blank?

        items_by_id[id.to_s]
      end

      def items_by_id
        @items_by_id ||= begin
          ids = placement_children.filter_map { |child| child.recordable.try(:item_recording_id) }.uniq
          fetch_recordings(ids).index_by { |recording| recording.id.to_s }
        end
      end

      def fetch_recordings(ids)
        return [] if ids.empty?

        scope = RecordingStudio::Recording.where(id: ids)
        scope = scope.includes(:recordable) if scope.respond_to?(:includes)
        Array(scope)
      end

      def usable_item?(item_recording)
        return false if item_recording.blank?
        return false if item_recording.recordable.blank?
        return false unless same_root?(parent_recording, item_recording)
        return false if Placements.library_recording?(item_recording)
        return false if Placements.placement_recording?(item_recording)
        return false unless include_trashed || item_recording.try(:trashed_at).blank?
        return false unless live_library_item?(item_recording)
        return false unless visible_to_actor?(item_recording)

        true
      end

      def visible_to_actor?(item_recording)
        RecordingStudioLibrary::Authorization.visible?(
          actor: actor,
          recording: item_recording,
          unfiltered: unfiltered
        )
      end
    end
  end
end
