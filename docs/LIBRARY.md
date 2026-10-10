# RecordingStudio Library

A Recording Studio addon that owns **a collection of things, and ordered pointers to them elsewhere**. It does not care whether an item is an image, a video, a sample, or anything else.

This gem is the generic extraction of the library/placement design from RecordingStudio Attachable v0.12/v0.13.

## What hosts get

- A thin keyed **library** on a workspace (or any parent that opts in). Hosts mount it. People never create, title, or index it.
- **Items** stay their own recordable types as ordinary children of the library. There is no wrapper type.
- **Placements** are pointers: they store the target item's recording id and an Orderable position. Captions and titles live on the item.
- A placement may point at a same-workspace item that is not in a library. It never points across workspaces.

```
Workspace
├── Library (key: default)
│   ├── Sample / image / video   <- the item gem's own recordable
│   └── Sample
├── Page                         <- outside the library, still placeable
└── Showcase
    ├── Placement -> sample
    └── Placement -> page
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

`Library.to` on a parent means that parent can hold libraries of those item types/keys.

`Placeable.to` on a holder means that holder can hold placements of those types from those libraries.

## Adapter registry

Item gems register an adapter per recordable type:

```ruby
RecordingStudioLibrary.register_adapter("RecordingStudioAttachable::Attachment", AttachableAdapter)
```

An adapter supplies thumbnail/preview, title, create/edit fields, full view, search text, and optionally a type label and icon. The gem ships `RecordingStudioLibrary::Adapters::Dummy` for `RecordingStudioLibrary::SampleItem` so the dummy app and tests work without Attachable or Video.

## Helpers

```ruby
RecordingStudioLibrary.library_for(parent, key: :default)
RecordingStudioLibrary.place!(holder, item)
RecordingStudioLibrary.place_new!(holder, library:, type:, attrs: {})
RecordingStudioLibrary.placements(holder) # same as resolve
RecordingStudioLibrary.reorder!(holder, ids)
RecordingStudioLibrary.remove!(placement)
RecordingStudioLibrary.resolve(holder, actor:)
RecordingStudioLibrary.usages(item)
```

`resolve` drops trashed or missing items, refuses cross-workspace pointers, and never returns items the actor cannot see (Accessible on the root covers the library and its items).

Trashing an in-use item warns with its usages. Deleting the item removes its placements. Trashable and Orderable APIs are reused as-is.

## UI

All screens are Flatpack ViewComponents.

- Library page: list and grid, mountable, `library_path_for(parent_or_library)`.
- Multi-select picker with search and type filter. Works standalone and as a Flatpack navigable modal (`flat_pack_modal_screen`, `data-fp-nav`). Hosts must pin `@hotwired/turbo-rails` so the modal's turbo-frame can load.
- Placements editor: Orderable list plus remove. Add opens the picker in a navigable modal.

Staff admin UI belongs in Recording Studio Admin, not here.

### Flatpack gaps (this gem did not invent replacements)

- No dedicated multi-select tile. Picker tiles are `FlatPack::Grid` cards wrapping `FlatPack::Checkbox`. Sample create/edit uses `FlatPack::TextInput` and `FlatPack::TextArea`.

## Install

1. Add the gem and pin Recording Studio, Orderable, Trashable, Accessible, and Flatpack from GitHub tags (see the README).
2. `bin/rails generate recording_studio_library:install`
3. `bin/rails generate recording_studio_library:migrations`
4. `bin/rails db:migrate`
5. Opt a parent into `Library.to` and a holder into `Placeable.to`.
6. Register adapters for each item type you place.

## What this gem does not do

- It does not replace Attachable or Video. Those gems keep their recordables and will register adapters in a later phase.
- It does not ship a separate admin surface.
- It does not invent captions, titles, or file handling on placements.
