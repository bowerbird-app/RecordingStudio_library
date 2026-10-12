# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-10-12

### Fixed
- `place!` and `resolve` refuse items that are not in a live library. Placing a same-workspace item from outside a library is no longer allowed.
- Authorization fails closed when Accessible is not loaded and no `authorize_with` adapter is set (`visible?` and `allowed?`).
- `current_library_actor` falls through a nil `Current.actor` to `current_user`.
- Library screens on the host default layout no longer render a second back control. They load `flat_pack/application` and the rounded theme. If the host has no `recording_studio_page_nav`, Library renders its own PageNav instead of showing none.
- `update_placements!` requires `:revise` on the item's library before saving shared item fields, and filters attributes with `permitted_item_keys` before calling the adapter.
- Reorder (drag handle and `PATCH .../placements/reorder`) uses `:revise` on the holder, matching collection PATCH. Add still uses `:upload`.

### Added
- `PATCH /recordings/:recording_id/placements` and `RecordingStudioLibrary.update_placements!` save submitted item fields through the item adapter, then reorder. See the API note below.
- Generic adapter `item_path` / `new_item_path` so hosts do not prepend helper overrides.
- Placements editor: one "Add from library" button, an Upload button from `library_new_item_path_for`, and List drag handles.
- Per-call `unfiltered:` on `resolve` / `placements` for trusted system jobs. `configuration.unfiltered_access` remains as a process-wide fallback. Anonymous resolve is unchanged.

### Tests
- Request test: an editor who can place on the holder cannot POST a real hidden item's id under an Accessible restriction.
- Renamed the Placeable item-type allow-list test.
- Refusal tests for placements PATCH: no `:revise` on the holder; an item not placed on this holder; another holder's placement in `ordered_recording_ids`; non-permitted keys; no `:revise` on the item's library.
- PageNav: host default layout keeps a single back control; missing `recording_studio_page_nav` falls back to Library's PageNav.

### Docs
- Hosts must call `library_for` before a library page or picker can find a library.

### Upgrade notes
- **Reorder now requires `:revise` on the holder, not `:upload`.** Drag handles on the placements editor and `PATCH /recordings/:recording_id/placements/reorder` authorize `:revise`. Add still uses `:upload`. Default `auth_roles` map both to `:edit`, so unchanged hosts are unaffected. Hosts that set custom `auth_roles` (for example `:upload` → `:edit` and `:revise` → `:admin`) must grant `:revise` to anyone who should reorder, or drag-reorder and the reorder route will be refused.

### Placements PATCH API (for Attachable)

`PATCH recording_placements_path(holder)` (same URL as index/create).

```ruby
RecordingStudioLibrary.update_placements!(
  holder,
  items: {
    item_or_placement_id => { caption: "…", credit: "…", alt_text: "…" }
  },
  ordered_recording_ids: [placement_id, …], # optional
  moving_recording_id: placement_id,        # optional, with target_position
  target_position: 2,
  actor: current_user
)
```

- Authorize `:revise` on the holder, then `:revise` on each item's library before `update_item!`. Editing one page cannot rename a shared library item unless the actor can revise that library.
- `items` keys may be a placement recording id or the placed item recording id. Unknown keys and items that are not on the holder are refused. Library filters attributes with the adapter's `permitted_item_keys` before calling `update_item!` (`title` on Base, `title` / `summary` / `accent` on Dummy). Attachable should implement `permitted_item_keys` as `%i[caption credit alt_text name description]` (or whichever columns it edits).
- After item saves, Library calls `reorder!` when `ordered_recording_ids` or `moving_recording_id` is present. Foreign placement ids are refused. Reorder itself also authorizes `:revise` on the holder.
- JSON/XHR returns `{ ok: true|false }`.
- Hosts should not implement a parallel update. Register adapter paths and keys; PATCH this route.

## [0.1.0] - 2026-10-10

### Added
- First release of RecordingStudio Library: keyed libraries, ordered placements, and a small adapter registry.
- Recordables `RecordingStudioLibrary::Library` (thin, found-or-created by key) and `RecordingStudioLibrary::Placement` (pointer to an item recording id).
- Capabilities `RecordingStudio::Capabilities::Library.to(types:, keys:)` and `RecordingStudio::Capabilities::Placeable.to(types:, libraries:)`.
- Helpers `library_for`, `find_library`, `place!`, `place_new!`, `placements`, `reorder!`, `remove!`, `resolve`, and `usages`.
- `resolve` drops trashed or missing items, refuses cross-workspace pointers, and respects Accessible visibility. Anonymous visitors go through Accessible. `configuration.unfiltered_access` is an opt-in unfiltered mode for system jobs.
- `place!` requires the actor can view the item. `place_new!` validates adapter, library types/keys, holder types, and upload rights before recording, then wraps record-and-place in a transaction.
- `Library.to` types and keys are enforced on every create-into-library path, including sample create.
- Delete cascade: destroying an item removes placements that pointed at it. Trashing an in-use item warns with its usages.
- Flatpack library page (list and grid), multi-select picker (standalone and navigable modal, Card tiles), and placements editor (reorder and remove). Reorder uses the same `:upload` permission as add. Card media uses Flatpack's edge-to-edge slot so thumbnails sit flush in the top of the card. The library add button is "+ {adapter type label}" with Flatpack's plus icon. The picker puts "Add selected" on the search row and uses Flatpack `unsaved-changes` so it turns primary only after a selection.
- Built-in dummy adapter and `SampleItem` so the gem is usable without Attachable or Video. Hosts must still register an adapter per type they place; unregistered types fall back to `Adapters::Base` for display only.
- Dummy app seeds a workspace library of samples and a showcase that places them.

### Upgrade notes
- New gem. Hosts add it, run the install and migrations generators, opt parents into `Library.to` and holders into `Placeable.to`, and register an adapter per item type.
- Pin Recording Studio `v4.4.0`, Accessible `v0.14.0`, Orderable `v0.2.8`, Trashable `v0.7.0`, Metrics `v0.2.2`, and Flatpack `v0.1.227` from GitHub tags.
- Use `find_library` on read paths. `library_for` remains the find-or-create write path.
- Attachable still owns its own Library/Placement until a later phase. Do not switch Presskits or Video onto this gem yet.
