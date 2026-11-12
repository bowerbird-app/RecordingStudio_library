# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-11-12

### Added
- Recording Studio API capability actions as thin wrappers over the existing helpers: `place`, `place_new`, `reorder_placements`, `remove_placement`, `open_library`, `find_library`, `libraries_for`, and `resolve_placements`.
- Dummy mounts Recording Studio API so hosts and MCP adapters can call those actions on types that enable `:library` or `:placeable`.

### Upgrade notes
- Pin `v0.5.0`. There is no library migration. Hosts that already have Recording Studio API get the actions when this gem loads. Enable them on the parent and holder recordable type APIs (`capability_actions`). Library and Placement stay off generic create/update.
- `place`, `place_new`, and `reorder_placements` need Accessible `:edit` (upload). `remove_placement` needs `:admin` (remove). `open_library` needs `:edit`. `find_library`, `libraries_for`, and `resolve_placements` need `:view`.
- Development and dummy Gemfiles pin Recording Studio API `v0.21.3`, Admin `v2.11.0`, Logs `v0.7.3`, Moveable `v4.1.0`, and Icons `v0.2.0`. API’s engine loads Admin screens.

## [0.4.0] - 2026-11-06

### Changed
- Library and placement access always go through Recording Studio Accessible `authorized?`. The gem depends on `recording_studio_accessible` `>= 0.24.2`.
- Removed `configuration.unfiltered_access` and `configuration.authorize_with`. Missing Accessible still denies.
- Require `recording_studio` `>= 6.5.0`. Root and dummy Gemfiles pin Recording Studio tag `v6.5.0`, Accessible `v0.24.2`, Trashable `v0.12.3`, Metrics `v0.7.3`, Orderable `v0.4.9`, and FlatPack `v0.1.341`. Dummy also pins Root Switchable `v0.11.7` and Cache `v0.6.3`.

### Upgrade notes
- Pin Recording Studio `>= 6.5.0` (tag `v6.5.0`) and Accessible `>= 0.24.2` (tag `v0.24.2`). Companion tags: Trashable `v0.12.3`, Metrics `v0.7.3`, Orderable `v0.4.9`. Dummy hosts that mount Root Switchable need `v0.11.7` and Cache `v0.6.3`.
- Delete `config.unfiltered_access` and `config.authorize_with`. System jobs and custom adapters must grant Accessible roles on the recording. Anonymous visitors stay denied unless Accessible allows `:view`.
- Hosts that copied the install initializer can drop those two commented settings. `auth_roles` still maps library actions onto Accessible roles.
- Recording Studio `6.5.0` fails closed on writes. Dummy (and hosts) must set `config.authorize_write` and pass an actor. The dummy delegates that core write gate to Accessible `authorized?` (`:edit` on the root). Access grant/bootstrap writes use Accessible `AccessCreationContext`, not `actor.present?`. Library visibility still goes through Accessible.

## [0.3.0] - 2026-11-05

### Changed
- Require `recording_studio` `>= 6.3.0`. Root and dummy Gemfiles pin Recording Studio tag `v6.3.0`, Accessible `v0.24.1`, Trashable `v0.12.2`, Metrics `v0.7.2`, Orderable `v0.4.8`, and FlatPack `v0.1.341`. Dummy also pins Root Switchable `v0.11.5` and Cache `v0.6.2`.
- Engine screens call `recording_studio_layout`. `configuration.layout` defaults to `nil` and is validated by `RecordingStudio::Layout.accept`. Legacy `:default` / `"default"` (and nil/blank) map to core's `DEFAULT_LAYOUT` before `Layout.accept`.
- Library page nav fills FlatPack `flat_pack_page_nav` (`with_back` / `with_close`). The old `FlatPack::PageNav` constructor fallback is gone.
- Library and picker cards drop FlatPack Card `style:`. Picker tiles use Grid `gap: :md`. Placements add actions use `ButtonGroup` `collapse: :menu`.
- Dropped template leftovers: `UPDATE_SUMMARY.md`, `MIGRATION_NOTES.md`, `docs/gem_template/`, and the unauthenticated engine `HomeController#index` ping plus its root route.
- Root and dummy lockfiles use Rails `8.1.4.1` and the November 2026 security floor (Rack, Loofah, Nokogiri, rails-html-sanitizer, crass, dummy net-ssh).

### Upgrade notes
- Pin Recording Studio `>= 6.3.0` (tag `v6.3.0`) and FlatPack `v0.1.341`. Companion tags: Accessible `v0.24.1`, Trashable `v0.12.2`, Metrics `v0.7.2`, Orderable `v0.4.8`. Dummy hosts that mount Root Switchable need `v0.11.5` and Cache `v0.6.2`.
- Leave `config.layout` `nil` to follow core's default layout, or pass a layout name, `false`, or a callable that accepts `controller:`. Existing `config.layout = :default` and YAML `layout: default` still resolve to core's `DEFAULT_LAYOUT`.
- Call `recording_studio_layout { RecordingStudioLibrary.configuration.layout }` on a replacement engine controller. Do not hard-code `layout "recording_studio/default_layout"`.
- Hosts that copied library or picker cards should drop Card `style:`. Hosts that copied the picker grid should pass `gap: :md` instead of `class: "items-stretch gap-4 …"`. Hosts that copied placements add buttons should wrap them in `ButtonGroup` `collapse: :menu`.
- Engine `/` is no longer a 200 ping. Mount a host route if you used that URL as a health check.

## [0.2.1] - 2026-11-02

### Changed
- Library grid uses FlatPack Grid `gap: :lg` instead of a raw `gap-6` class. Align stays the Grid default (`items-stretch`).
- Dummy Sign out uses Button `href:` (FlatPack ≥ 0.1.177). `url:` rendered a dead `<button url="…">`.

### Upgrade notes
- Hosts that copied `_grid.html.erb` should pass `gap: :lg` and drop `class: "items-stretch gap-6"`. Keep `lg:grid-cols-5` if you still want five columns on large screens.
- Hosts on FlatPack ≥ 0.1.177 should pass Button `href:`, not `url:`.

## [0.2.0] - 2026-11-02

### Changed
- Item destroy still removes pointing placements, via Recording Studio's `extend_model(:recording)` hook instead of including into core `Recording`.
- Hosts opt in to model and controller extensions by calling `RecordingStudioLibrary::Engine.apply_model_extensions` / `apply_controller_extensions`. The engine no longer walks every ActiveRecord and ActionController descendant.
- Library access checks go through Accessible `allowed?` (or a host `authorize_with` adapter). Capability checks use `RecordingStudio.capability_enabled?(name, for: type)` only.
- `place!` records placements with `RecordingStudio.record!` and fails when Orderable append fails.
- Sample edit uses `revise`. Sample trash uses Trashable only.
- YAML and `config.x` load no longer swallow unexpected errors. A missing YAML file is still skipped.

### Upgrade notes
- This is a minor bump: hosts must call `apply_model_extensions` / `apply_controller_extensions` on the classes they register with `hooks.extend_model` / `extend_controller`. Descendants no longer get those procs for free.
- `place!` raises when Orderable cannot append the new placement.
- Sample PATCH writes a new recordable snapshot and an `updated` event. Sample DELETE requires Trashable.
- `authorize_with` and `unfiltered_access` are unchanged in this release.

## [0.1.4] - 2026-11-02

### Changed
- `version.rb` is `0.1.4`. Tags `v0.1.1` to `v0.1.3` moved Accessible to `v0.15.0` (`v0.1.1`), Trashable to `v0.8.0` (`v0.1.2`), and Orderable to `v0.3.0` (`v0.1.3`) while `version.rb` stayed `0.1.0`.
- Dummy PostgreSQL defaults are `recording_studio_library_development` and `recording_studio_library_test`.
- Security and CI lint Ruby setup use `3.3` so `setup-ruby` can resolve a current patch on `ubuntu-26.04`. Matrix test jobs stay on `3.3` / `3.4`.
- Dummy SimpleCov output under `test/dummy/coverage/` is untracked.

### Upgrade notes
- Point the gem at tag `v0.1.4` when that GitHub Release exists. Until then, pin the commit on this branch.
- Recreate dummy databases if you still have `app_development` / `app_test` from the template defaults.

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

[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.1.4...v0.2.0
[0.1.4]: https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.1.0...v0.1.4
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_library/releases/tag/v0.1.0
