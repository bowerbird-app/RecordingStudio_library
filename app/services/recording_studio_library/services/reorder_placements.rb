# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class ReorderPlacements < ApplicationService
      def initialize(parent_recording:, ordered_recording_ids: nil, moving_recording_id: nil, target_position: nil, actor: nil)
        @parent_recording = parent_recording
        @ordered_recording_ids = ordered_recording_ids
        @moving_recording_id = moving_recording_id
        @target_position = target_position
        @actor = actor
      end

      private

      attr_reader :parent_recording, :ordered_recording_ids, :moving_recording_id, :target_position, :actor

      def perform
        require_recording_studio!
        parent = require_parent!
        assert_placement_enabled!(parent)
        authorize_placement!(action: :revise, actor: resolve_actor(actor), recording: parent)
        raise ArgumentError, I18n.t("recording_studio.library.errors.cannot_reorder") unless orderable?(parent)

        if moving_recording_id.present?
          move!(parent)
        else
          reorder!(parent)
        end
        success(parent)
      end

      def require_parent!
        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required") if parent_recording.blank?

        parent_recording
      end

      def orderable?(parent)
        parent.respond_to?(:recording_studio_orderable_reorder!)
      end

      def reorder!(parent)
        ids = Array(ordered_recording_ids).map(&:to_s)
        owned = owned_placement_ids(parent)
        deny!(:placement_not_on_page) if ids.any? { |id| owned.exclude?(id) }

        parent.recording_studio_orderable_reorder!(
          ordered_recording_ids: Array(ordered_recording_ids),
          actor: resolve_actor(actor)
        )
      end

      def move!(parent)
        moving = owned_placement(parent, moving_recording_id)
        deny!(:placement_not_on_page) if moving.blank?

        to_index = target_position.to_i - 1
        to_index = 0 if to_index.negative?

        parent.recording_studio_orderable_move!(
          moving,
          to_index: to_index,
          actor: resolve_actor(actor)
        )
      end

      def owned_placement(parent, id)
        Array(placement_recordings(parent)).find do |child|
          child.id.to_s == id.to_s && Placements.placement_recording?(child)
        end
      end

      def owned_placement_ids(parent)
        Array(placement_recordings(parent)).filter_map do |child|
          child.id.to_s if Placements.placement_recording?(child)
        end
      end

      def placement_recordings(parent)
        if parent.respond_to?(:recording_studio_orderable_children)
          Array(parent.recording_studio_orderable_children)
        else
          Array(parent.try(:child_recordings))
        end
      end
    end
  end
end
