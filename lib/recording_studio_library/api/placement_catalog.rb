# frozen_string_literal: true

require_relative "placement_handlers"
require_relative "serializer"

module RecordingStudioLibrary
  module Api
    module PlacementCatalog
      ENTRIES = [
        {
          name: :library_place,
          capability: :placeable,
          required_role: :edit,
          handler: PlacementHandlers::Place,
          serializer: Serializer.method(:recording),
          title: "Library - Place",
          description: "Places an existing item under this holder. The caller needs Library " \
                       "upload on the holder and Library view on the item. The item must be " \
                       "in the same workspace.",
          fields: {
            item_recording_id: { type: :string, required: true, allow_blank: false }
          }
        },
        {
          name: :library_place_new,
          capability: :placeable,
          required_role: :edit,
          handler: PlacementHandlers::PlaceNew,
          serializer: Serializer.method(:recording),
          title: "Library - Place New",
          description: "Records a new library item and places it under this holder in one " \
                       "step. The caller needs Library upload on both the holder and the " \
                       "library. The type must have a registered adapter.",
          fields: {
            library_id: { type: :string, required: true, allow_blank: false },
            type: { type: :string, required: true, allow_blank: false },
            attrs: { type: :hash, required: false }
          }
        },
        {
          name: :library_reorder_placements,
          capability: :placeable,
          required_role: :edit,
          handler: PlacementHandlers::ReorderPlacements,
          serializer: Serializer.method(:recording),
          title: "Library - Reorder Placements",
          description: "Reorders placements on this holder. This is Library's own reorder, " \
                       "not generic Orderable. The caller needs Library upload on the holder.",
          fields: {
            ordered_recording_ids: { type: :array, required: false },
            moving_recording_id: { type: :string, required: false, allow_blank: false },
            target_position: { type: :integer, required: false }
          }
        },
        {
          name: :library_remove_placement,
          capability: :placeable,
          required_role: :admin,
          handler: PlacementHandlers::RemovePlacement,
          serializer: Serializer.method(:recording),
          title: "Library - Remove Placement",
          description: "Removes a placement from this holder. The caller needs Library " \
                       "remove on the holder. The placement must belong to this holder.",
          fields: {
            placement_id: { type: :string, required: true, allow_blank: false }
          }
        },
        {
          name: :library_resolve_placements,
          capability: :placeable,
          required_role: :view,
          handler: PlacementHandlers::ResolvePlacements,
          serializer: Serializer.method(:placements),
          title: "Library - Resolve Placements",
          description: "Resolves placements on this holder, skipping trash, other workspaces, " \
                       "and items the caller cannot see. The caller needs Library view on " \
                       "the holder."
        }
      ].freeze
    end
  end
end
