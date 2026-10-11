# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Flatpack library page (list and grid), multi-select picker (standalone and navigable modal, Card tiles), and placements editor (reorder and remove). Reorder uses the same `:upload` permission as add.
- Built-in dummy adapter and `SampleItem` so the gem is usable without Attachable or Video. Hosts must still register an adapter per type they place; unregistered types fall back to `Adapters::Base` for display only.
- Dummy app seeds a workspace library of samples and a showcase that places them.

### Upgrade notes
- New gem. Hosts add it, run the install and migrations generators, opt parents into `Library.to` and holders into `Placeable.to`, and register an adapter per item type.
- Pin Recording Studio `v4.4.0`, Accessible `v0.14.0`, Orderable `v0.2.8`, Trashable `v0.7.0`, Metrics `v0.2.2`, and Flatpack `v0.1.227` from GitHub tags.
- Use `find_library` on read paths. `library_for` remains the find-or-create write path.
- Attachable still owns its own Library/Placement until a later phase. Do not switch Presskits or Video onto this gem yet.
