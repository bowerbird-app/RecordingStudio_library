# frozen_string_literal: true

require_relative "errors"
require_relative "lookup"

module RecordingStudioLibrary
  module Api
    module PlacementHandlers
      class Place
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioLibrary.place!(
              context.recording,
              Lookup.recording!(context.params[:item_recording_id]),
              actor: context.actor
            )
          end
        end
      end

      class PlaceNew
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioLibrary.place_new!(
              context.recording,
              library: Lookup.recording!(context.params[:library_id]),
              type: context.params[:type],
              attrs: context.params[:attrs] || {},
              actor: context.actor
            )
          end
        end
      end

      class ReorderPlacements
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioLibrary.reorder!(
              context.recording,
              context.params[:ordered_recording_ids],
              actor: context.actor,
              moving_recording_id: context.params[:moving_recording_id],
              target_position: context.params[:target_position]
            )
          end
        end
      end

      class RemovePlacement
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :admin)
            RecordingStudioLibrary.remove!(
              Lookup.recording!(context.params[:placement_id]),
              holder: context.recording,
              actor: context.actor
            )
          end
        end
      end

      class ResolvePlacements
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :view)
            RecordingStudioLibrary.resolve(
              context.recording,
              include_trashed: context.params[:include_trashed] || false,
              actor: context.actor
            )
          end
        end
      end
    end
  end
end
