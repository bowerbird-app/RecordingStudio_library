# frozen_string_literal: true

require_relative "errors"
require_relative "lookup"

module RecordingStudioLibrary
  module Api
    module PlacementHandlers
      class Place
        def self.call(context)
          Errors.wrap do
            RecordingStudioLibrary::Authorization.authorize_placement!(action: :upload, actor: context.actor, recording: context.recording)
            RecordingStudioLibrary.place!(
              context.recording,
              Lookup.recording!(context.params[:item_recording_id], context),
              actor: context.actor
            )
          end
        end
      end

      class PlaceNew
        def self.call(context)
          Errors.wrap do
            RecordingStudioLibrary::Authorization.authorize_placement!(action: :upload, actor: context.actor, recording: context.recording)
            RecordingStudioLibrary.place_new!(
              context.recording,
              library: Lookup.recording!(context.params[:library_id], context),
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
            RecordingStudioLibrary::Authorization.authorize_placement!(action: :upload, actor: context.actor, recording: context.recording)
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
            RecordingStudioLibrary::Authorization.authorize_placement!(action: :remove, actor: context.actor, recording: context.recording)
            RecordingStudioLibrary.remove!(
              Lookup.recording!(context.params[:placement_id], context),
              holder: context.recording,
              actor: context.actor
            )
          end
        end
      end

      class ResolvePlacements
        def self.call(context)
          Errors.wrap do
            RecordingStudioLibrary::Authorization.authorize_placement!(action: :view, actor: context.actor, recording: context.recording)
            RecordingStudioLibrary.resolve(context.recording, actor: context.actor)
          end
        end
      end
    end
  end
end
