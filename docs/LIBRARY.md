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

`Library.to` on a parent means that parent can hold libraries of those item types/keys. Those lists are enforced whenever an item is recorded into a library (`place_new!`, sample create, `RecordLibraryItem`). Empty lists mean unrestricted.

The engine registers `Library`, `Placement`, and `SampleItem` only after those classes have declared `recording_studio_recordable`. It does not add a type that has not declared.

`Placeable.to` on a holder means that holder can hold placements of those types from those libraries. Reorder and add both use the `:upload` role, matching the placements editor.

## Adapter registry

Hosts **must register an adapter per recordable type** they place or create:

```ruby
RecordingStudioLibrary.register_adapter("RecordingStudioAttachable::Attachment", AttachableAdapter)
```

An adapter supplies thumbnail/preview, title, create/edit fields, full view, search text, and optionally a type label and icon. Unregistered types fall back to `RecordingStudioLibrary::Adapters::Base` for display only. `place_new!` refuses them. The gem ships `RecordingStudioLibrary::Adapters::Dummy` for `RecordingStudioLibrary::SampleItem` so the dummy app and tests work without Attachable or Video.

## Helpers

```ruby
RecordingStudioLibrary.library_for(parent, key: :default) # find or create
RecordingStudioLibrary.find_library(parent, key: :default) # find only, used on GET
RecordingStudioLibrary.place!(holder, item)
RecordingStudioLibrary.place_new!(holder, library:, type:, attrs: {})
RecordingStudioLibrary.placements(holder) # same as resolve
RecordingStudioLibrary.reorder!(holder, ids)
RecordingStudioLibrary.remove!(placement)
RecordingStudioLibrary.resolve(holder, actor:)
RecordingStudioLibrary.usages(item)
```

`library_for` is the write path. Screens that only look up a library use `find_library` so a GET cannot create one.

Recording Studio API exposes the same helpers as capability actions (`library_place`, `library_open_library`, and the rest). Enable them on the host types that already have `:library` or `:placeable`. Library and Placement stay off generic API create/update.

`place!` records the placement with `RecordingStudio.record!`, then appends it with Orderable. It requires the actor can view the item, the item is in the same workspace, and the holder allows that type. If Orderable append fails, `place!` fails. `place_new!` checks the registered adapter, library types/keys, holder types, and upload rights on both the holder and the library, then records the item and places it in one transaction.

`resolve` drops trashed or missing items, refuses cross-workspace pointers, and never returns items the actor cannot see. Access checks call Accessible `authorized?`. Anonymous visitors and system jobs go through Accessible too. Grant a system actor on the recording instead of bypassing access.

Sample edit uses `revise`. Sample trash uses `recording_studio_trashable_trash!` only.

Trashing an in-use item warns with its usages. Destroying the item recording removes placements that pointed at it. Register that cleanup with Recording Studio `hooks.extend_model(:recording)` (the engine does this). Trashable and Orderable APIs are reused as-is.

Model and controller hook procs apply only when the host calls `RecordingStudioLibrary::Engine.apply_model_extensions(YourModel)` or `apply_controller_extensions(YourController)`.

## UI

All screens are Flatpack ViewComponents.

- Library page: list and grid, mountable, `library_path_for(parent_or_library)`. The grid is FlatPack Grid (`cols: 2`, `gap: :lg`, `lg:grid-cols-5`). Cards do not pass `style:`. The list is preview plus name (type under the title).
- Multi-select picker with search and type filter. Lists **library items only**. Works standalone and as a Flatpack navigable modal (`flat_pack_modal_screen`, `data-fp-nav`). Hosts must pin `@hotwired/turbo-rails` so the modal's turbo-frame can load. Tiles are Flatpack Cards wrapping a checkbox on Grid `gap: :md`.
- Placements editor: Orderable list plus remove. Add and the standalone picker sit in a `ButtonGroup` (`collapse: :menu`). Add opens the picker in a navigable modal. Reorder uses the same `:upload` permission as add.
- Sample show: Edit is gated with `library_allowed?(:revise, library)`. Edit and trash sit in a `ButtonGroup` (`collapse: :menu`).

Engine screens call `recording_studio_layout { RecordingStudioLibrary.configuration.layout }`. A `nil` setting follows the host core layout, then `RecordingStudio::DEFAULT_LAYOUT`. They fill FlatPack `flat_pack_page_nav` (back and close) instead of rendering a second PageNav.

Staff admin UI belongs in Recording Studio Admin, not here.

### Flatpack gaps (this gem did not invent replacements)

- No dedicated multi-select tile. Picker tiles are `FlatPack::Card` wrapping `FlatPack::Checkbox`. Sample create/edit uses `FlatPack::TextInput` and `FlatPack::TextArea`.

## Install

1. Add the gem and pin Recording Studio `>= 6.5.0`, Accessible `>= 0.24.2`, Orderable, Trashable, and Flatpack from GitHub tags (see the README). Leave `config.layout` nil unless the host needs a different shell.
2. `bin/rails generate recording_studio_library:install`
3. `bin/rails generate recording_studio_library:migrations`
4. `bin/rails db:migrate`
5. Opt a parent into `Library.to` and a holder into `Placeable.to`.
6. Register adapters for each item type you place. This is required, not optional.

## What this gem does not do

- It does not replace Attachable or Video. Those gems keep their recordables and will register adapters in a later phase.
- It does not ship a separate admin surface.
- It does not invent captions, titles, or file handling on placements.
- The picker does not list same-workspace items that live outside a library. Use `place!` for that case.
