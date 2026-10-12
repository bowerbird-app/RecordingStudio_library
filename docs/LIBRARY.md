# RecordingStudio Library

A Recording Studio addon that owns **a collection of things, and ordered pointers to them elsewhere**. It does not care whether an item is an image, a video, a sample, or anything else.

This gem is the generic extraction of the library/placement design from RecordingStudio Attachable v0.12/v0.13.

## What hosts get

- A thin keyed **library** on a workspace (or any parent that opts in). Hosts mount it. People never create, title, or index it.
- **Items** stay their own recordable types as ordinary children of the library. There is no wrapper type.
- **Placements** are pointers: they store the target item's recording id and an Orderable position. Captions and titles live on the item.
- A placement may only point at an item that lives in a live library in the same workspace. It never points across workspaces.

```
Workspace
├── Library (key: default)
│   ├── Sample / image / video   <- the item gem's own recordable
│   └── Sample
├── Page                         <- outside the library, not placeable
└── Showcase
    ├── Placement -> sample
    └── Placement -> sample
```

## Capabilities

```ruby
include RecordingStudio::Capabilities::Library.to(
  types: ["RecordingStudioLibrary::SampleItem", "RecordingStudioAttachable::Attachment"],
  keys: [:default, :logos]
)

include RecordingStudio::Capabilities::Placeable.to(
  types: ["RecordingStudioLibrary::SampleItem", "RecordingStudioAttachable::Attachment"],
  libraries: [:default]
)
```

`.to` is the usual Recording Studio `include_for` wrapper. Allowed types and keys are host config at declaration, not stored data.

`Library.to` on a parent means that parent can hold libraries of those item types/keys. Those lists are enforced whenever an item is recorded into a library (`place_new!`, sample create, `RecordLibraryItem`). Empty lists mean unrestricted.

`Placeable.to` on a holder means that holder can hold placements of those types from those libraries. Reorder and add both use the `:upload` role, matching the placements editor.

## Adapter registry

Hosts **must register an adapter per recordable type** they place or create:

```ruby
RecordingStudioLibrary.register_adapter("RecordingStudioAttachable::Attachment", AttachableAdapter)
```

An adapter supplies thumbnail/preview, title, create/edit fields, full view, search text, and optionally a type label, icon, `item_path` / `new_item_path`, and `permitted_item_keys` for collection PATCH. Unregistered types fall back to `RecordingStudioLibrary::Adapters::Base` for display only. `place_new!` refuses them. The gem ships `RecordingStudioLibrary::Adapters::Dummy` for `RecordingStudioLibrary::SampleItem` so the dummy app and tests work without Attachable or Video. Hosts like Attachable should implement `item_path` and `new_item_path` on the adapter instead of prepending helper overrides.

## Helpers

```ruby
RecordingStudioLibrary.library_for(parent, key: :default) # find or create
RecordingStudioLibrary.find_library(parent, key: :default) # find only, used on GET
RecordingStudioLibrary.place!(holder, item)
RecordingStudioLibrary.place_new!(holder, library:, type:, attrs: {})
RecordingStudioLibrary.placements(holder) # same as resolve
RecordingStudioLibrary.reorder!(holder, ids)
RecordingStudioLibrary.update_placements!(holder, items:, ordered_recording_ids:)
RecordingStudioLibrary.remove!(placement)
RecordingStudioLibrary.resolve(holder, actor:, unfiltered: false)
RecordingStudioLibrary.usages(item)
```

`library_for` is the write path. Call it before a library page or picker can find a library. Screens that only look up a library use `find_library` so a GET cannot create one.

`place!` requires the actor can view the item, the item is in a live library in the same workspace, and the holder allows that type. `place_new!` checks the registered adapter, library types/keys, holder types, and upload rights on both the holder and the library, then records the item and places it in one transaction.

`resolve` drops trashed or missing items, items that are not in a live library, refuses cross-workspace pointers, and never returns items the actor cannot see. Anonymous visitors go through Accessible. Trusted system jobs should pass `unfiltered: true` on that call. `configuration.unfiltered_access` remains as a process-wide fallback.

Authorization fails closed when Accessible is not loaded and no `authorize_with` adapter is set.

Collection editors `PATCH recording_placements_path(holder)` with `items` (item or placement id → adapter fields) and optional `ordered_recording_ids` / `moving_recording_id` + `target_position`. Library saves permitted fields through the item adapter, then calls `reorder!`.

Trashing an in-use item warns with its usages. Deleting the item removes its placements. Trashable and Orderable APIs are reused as-is.

## UI

All screens are Flatpack ViewComponents.

- Library page: list and grid, mountable, `library_path_for(parent_or_library)`.
- Multi-select picker with search and type filter. Lists **library items only**. Works standalone and as a Flatpack navigable modal (`flat_pack_modal_screen`, `data-fp-nav`). Hosts must pin `@hotwired/turbo-rails` so the modal's turbo-frame can load. Tiles are Flatpack Cards wrapping a checkbox.
- Placements editor: Orderable list with a drag handle, remove, one "Add from library" button (picker modal), and Upload (adapter `new_item_path`). Reorder uses the same `:upload` permission as add. Collection PATCH uses `:revise`.

When the host uses Recording Studio's default layout, engine screens fill that layout's PageNav slots instead of rendering a second PageNav, and they load `flat_pack/application` plus the rounded theme on `body`.

Staff admin UI belongs in Recording Studio Admin, not here.

### Flatpack gaps (this gem did not invent replacements)

- No dedicated multi-select tile. Picker tiles are `FlatPack::Card` wrapping `FlatPack::Checkbox`. Sample create/edit uses `FlatPack::TextInput` and `FlatPack::TextArea`.
- List has `handle_selector` but no Handle component. CollectionEditor's handle is private to that component. Placements reuse `bars-3` plus `handle_selector`.
- Recording Studio's default layout puts `data-theme` on `body`, not `html`. Library does not change Flatpack or Recording Studio.

## Install

1. Add the gem and pin Recording Studio, Orderable, Trashable, Accessible, and Flatpack from GitHub tags (see the README).
2. `bin/rails generate recording_studio_library:install`
3. `bin/rails generate recording_studio_library:migrations`
4. `bin/rails db:migrate`
5. Opt a parent into `Library.to` and a holder into `Placeable.to`.
6. Register adapters for each item type you place. This is required, not optional.

## What this gem does not do

- It does not replace Attachable or Video. Those gems keep their recordables and will register adapters in a later phase.
- It does not ship a separate admin surface.
- It does not invent captions, titles, or file handling on placements.
- The picker does not list same-workspace items that live outside a library. `place!` and `resolve` refuse those items too.
