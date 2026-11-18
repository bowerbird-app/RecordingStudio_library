# RecordingStudio Library

A Recording Studio addon that owns a collection of things, and ordered pointers to them elsewhere. Items stay their own types. Libraries are keyed and host-mounted. Placements only store what is pointed at and in what order.

Version **0.6.0**. Recording Studio dummy GitHub tag `v7.7.1`, Accessible `v0.54.1`, Orderable `v0.11.0`, Trashable `v1.2.1`, Metrics `v0.9.2`, Cache `v0.7.1`, Root Switchable `v0.16.0`, Flatpack `v0.1.378`, API `v1.16.0`, Admin `v2.19.0`, Logs `v0.8.1`, Moveable `v6.0.2`, Icons `v0.4.2`. The gemspec requires `recording_studio` `~> 7.7`.

## What it does

- Opens a keyed library on first use (`library_for(parent, key: :default)`). People never create or title it. Read paths use `find_library`, which never creates.
- Keeps items as ordinary child recordings of that library. `Library.to(types:, keys:)` is enforced whenever an item is recorded into a library.
- Places ordered pointers under a holder (`place!`, `reorder!`, `remove!`). `place!` requires the actor can view the item. The picker lists library items only; placing a same-workspace item from outside a library stays API-only.
- Resolves those pointers for display, skipping trash, missing items, other workspaces, and anything the actor cannot see. Visibility and library/placement actions go through Accessible. Anonymous visitors and system jobs need an Accessible grant like everyone else.
- Renders everything through a small adapter registry. Hosts must register an adapter per item type. Unregistered types fall back to `Adapters::Base` for display only, and cannot be recorded through `place_new!`.

See [docs/LIBRARY.md](docs/LIBRARY.md) for the recording tree, capabilities, helpers, and UI.

## Dummy app

`test/dummy/` is a host app that mounts the engine.

Sign in at `/users/sign_in`:

| Field    | Value             |
|----------|-------------------|
| Email    | admin@admin.com   |
| Password | Password          |

Useful routes after sign-in:

- `/` — demo home, links into the library, picker, and placements editor
- `/recording_studio_library/libraries/:id` — library list and grid
- `/recording_studio_library/recordings/:id/picker` — standalone picker
- `/recording_studio_library/recordings/:id/placements` — placements editor (opens the picker in a navigable modal)

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

## Install in a host

```ruby
# Gemfile
gem "recording_studio_library", github: "bowerbird-app/RecordingStudio_library", tag: "v0.6.0"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v7.7.1"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.54.1"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.11.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.2.1"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.378"
```

```bash
bin/rails generate recording_studio_library:install
bin/rails generate recording_studio_library:migrations
bin/rails db:migrate
bin/rails tailwindcss:build
```

Hosts MUST run the Recording Studio migrations from 7.4, 7.5, and 7.7 before booting this gem on 7.7. Those are `20261116230000_add_recording_studio_recordings_root_type_creation_index`, `20261117120000_enforce_recording_studio_recording_root_invariant`, and `20261117200000_replace_recording_studio_recordings_root_index`. Copy them from the Recording Studio engine (`bin/rails recording_studio:install:migrations`). This gem's dummy app does not carry those three migrations. A host that has not applied Recording Studio 6.9's `20261114090000_add_root_recording_id_to_recording_studio_events` MUST run that one too. Trashable `purge_at` on `recording_studio_recordings` is also required.

`RecordingStudio.root_recording_for` only finds a root. Create one with `RecordingStudio.create_root_recording!(recordable, actor:)` and allow that write when `root_recording` is nil. Do not list `RecordingStudioApi::AdminApi` in `recordable_types` unless an admin root type is configured. Hosts that mount Admin MUST set Accessible `config.admin_root_resolver`.

Then opt a parent into `Library.to` and a holder into `Placeable.to`, and register an adapter per item type. Pin `@hotwired/turbo-rails` in the host importmap so the placements picker can load inside a navigable modal. Staff screens belong in Recording Studio Admin, not in this gem.

If the host mounts Recording Studio API, this gem registers capability actions (`library_place`, `library_place_new`, `library_reorder_placements`, `library_remove_placement`, `library_open_library`, `library_find_library`, `library_libraries_for`, `library_resolve_placements`). Enable those names on the parent and holder type APIs. Do not expose generic Library or Placement create/update.

## Development

Gem tests (no dummy database):

```bash
bundle exec rake test
```

Dummy integration tests:

```bash
bundle exec rake test:dummy
```

Both:

```bash
bundle exec rake test:all
```

Product behaviour for this gem lives in `docs/LIBRARY.md`.
