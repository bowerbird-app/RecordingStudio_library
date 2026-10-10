# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class Place < ApplicationService
      def initialize(parent_recording:, item_recording:, actor: nil, impersonator: nil)
        @parent_recording = parent_recording
        @item_recording = item_recording
        @actor = actor
        @impersonator = impersonator
      end

      private

      attr_reader :parent_recording, :item_recording, :actor, :impersonator

      def perform
        require_recording_studio!
        parent = require_parent!
        item = require_item!
        assert_placement_enabled!(parent)
        assert_same_root!(parent, item)
        assert_placeable_type!(parent, item)
        assert_library_allowed!(parent, item)
        authorize_placement!(action: :upload, actor: resolve_actor(actor), recording: parent)

        placement = record_placement(parent, item)
        append_order(parent, placement)
        success(placement)
      end

      def require_parent!
        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required") if parent_recording.blank?

        parent_recording
      end

      def require_item!
        deny!(:item_required) if item_recording.blank? || !item_recording.respond_to?(:recordable_type)
        deny!(:cannot_place_library) if Placements.library_recording?(item_recording)
        deny!(:cannot_place_placement) if Placements.placement_recording?(item_recording)

        item_recording
      end

      def record_placement(parent, item)
        parent.record(RecordingStudioLibrary::Placement, parent_recording: parent, actor: resolve_actor(actor)) do |placement|
          placement.item_recording_id = item.id
        end
      end

      def append_order(parent, placement)
        return unless parent.respond_to?(:recording_studio_orderable_append!)

        parent.recording_studio_orderable_append!(placement, actor: resolve_actor(actor))
      rescue StandardError
        placement
      end
    end
  end
end
