# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    class UpdatePlacements < ApplicationService
      def initialize(parent_recording:, items: {}, ordered_recording_ids: nil, moving_recording_id: nil, target_position: nil,
                     actor: nil)
        @parent_recording = parent_recording
        @items = items
        @ordered_recording_ids = ordered_recording_ids
        @moving_recording_id = moving_recording_id
        @target_position = target_position
        @actor = actor
      end

      private

      attr_reader :parent_recording, :items, :ordered_recording_ids, :moving_recording_id, :target_position, :actor

      def perform
        require_recording_studio!
        parent = require_parent!
        resolved_actor = resolve_actor(actor)
        assert_placement_enabled!(parent)
        authorize_placement!(action: :revise, actor: resolved_actor, recording: parent)

        in_transaction do
          apply_item_updates!(parent, resolved_actor)
          reorder_if_needed!(parent, resolved_actor)
        end

        success(parent)
      end

      def require_parent!
        raise ArgumentError, I18n.t("recording_studio.library.errors.parent_required") if parent_recording.blank?

        parent_recording
      end

      def apply_item_updates!(parent, resolved_actor)
        item_updates.each do |id, attrs|
          item = item_for(parent, id, resolved_actor)
          library = library_for_item(item)
          deny!(:item_not_in_library) unless live_library?(library)
          RecordingStudioLibrary::Authorization.authorize_library!(
            action: :revise,
            actor: resolved_actor,
            recording: library
          )
          adapter = RecordingStudioLibrary.adapter_for(item)
          adapter.update_item!(permitted_attrs_for(adapter, attrs), actor: resolved_actor)
        end
      end

      def reorder_if_needed!(parent, resolved_actor)
        return unless order_requested?

        result = ReorderPlacements.call(
          parent_recording: parent,
          ordered_recording_ids: ordered_recording_ids,
          moving_recording_id: moving_recording_id,
          target_position: target_position,
          actor: resolved_actor
        )
        raise ArgumentError, result.error if result.failure?
      end

      def order_requested?
        Array(ordered_recording_ids).any? || moving_recording_id.present?
      end

      def item_updates
        raw = items.respond_to?(:to_unsafe_h) ? items.to_unsafe_h : items
        return {} if raw.blank?

        raw.to_h.each_with_object({}) do |(id, attrs), memo|
          next if id.blank?

          memo[id.to_s] = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h
        end
      end

      def in_transaction(&)
        if defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:connected?) && ActiveRecord::Base.connected?
          ActiveRecord::Base.transaction(&)
        else
          yield
        end
      end

      def item_for(parent, id, resolved_actor)
        resolved = Placements.resolve(parent, actor: resolved_actor)
        match = resolved.find do |entry|
          entry.placement_recording.id.to_s == id.to_s || entry.item_recording.id.to_s == id.to_s
        end
        deny!(:placement_not_on_page) if match.blank?

        match.item_recording
      end

      def permitted_attrs_for(adapter, attrs)
        keys = Array(adapter.permitted_item_keys).map(&:to_s)
        hash = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h
        hash.each_with_object({}) do |(key, value), memo|
          next unless keys.include?(key.to_s)

          memo[key.to_sym] = value
        end
      end
    end
  end
end
