# frozen_string_literal: true

require "recording_studio"

module RecordingStudioLibrary
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class DependencyUnavailableError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def library_for(parent, key: :default, actor: nil)
      unwrap!(
        Services::FindOrCreateLibrary.call(parent_recording: parent, key: key, actor: actor),
        fallback: "Could not open the library"
      )
    end

    def libraries_for(parent)
      Services::LibraryQuery.live_for_parent(parent)
    end

    def libraries_in_root(recording)
      Services::LibraryQuery.live_in_root(recording)
    end

    def place!(holder, item, actor: nil)
      unwrap!(
        Services::Place.call(parent_recording: holder, item_recording: item, actor: actor),
        fallback: "Could not add that item"
      )
    end

    def place_new!(holder, library:, type:, attrs: {}, actor: nil)
      unwrap!(
        Services::PlaceNew.call(
          parent_recording: holder,
          library_recording: library,
          type: type,
          attrs: attrs,
          actor: actor
        ),
        fallback: "Could not add that item"
      )
    end

    def placements(holder, include_trashed: false, actor: nil)
      resolve(holder, include_trashed: include_trashed, actor: actor)
    end

    def reorder!(holder, ids = nil, actor: nil, moving_recording_id: nil, target_position: nil)
      unwrap!(
        Services::ReorderPlacements.call(
          parent_recording: holder,
          ordered_recording_ids: ids,
          moving_recording_id: moving_recording_id,
          target_position: target_position,
          actor: actor
        ),
        fallback: "Could not reorder"
      )
    end

    def remove!(placement, holder: nil, actor: nil)
      unwrap!(
        Services::RemovePlacement.call(
          parent_recording: holder || placement.try(:parent_recording),
          placement_recording: placement,
          actor: actor
        ),
        fallback: "Could not remove that item"
      )
    end

    def resolve(holder, include_trashed: false, actor: nil)
      Placements.resolve(holder, include_trashed: include_trashed, actor: actor)
    end

    def usages(item)
      if Placements.library_recording?(item)
        Placements.usage_for_library(item)
      else
        Placements.usage_for(item)
      end
    end

    def register_adapter(type, adapter_class)
      Adapters.register(type, adapter_class)
    end

    def adapter_for(recording)
      Adapters.wrap(recording)
    end

    private

    def unwrap!(result, fallback:)
      raise ArgumentError, result.error.presence || fallback if result.failure?

      result.value
    end
  end
end

require "recording_studio_library/version"
require "recording_studio_library/configuration"
require "recording_studio_library/adapters"
require "recording_studio_library/adapters/base"
require "recording_studio_library/adapters/dummy"
require "recording_studio_library/placements"
require "recording_studio_library/authorization"
require "recording_studio_library/purge"
require "recording_studio/capabilities/library"
require "recording_studio/capabilities/placeable"
require "recording_studio_library/engine"

RecordingStudioLibrary.register_adapter("RecordingStudioLibrary::SampleItem", RecordingStudioLibrary::Adapters::Dummy)
