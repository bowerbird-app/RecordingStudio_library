# RecordingStudio Library

A Recording Studio addon that owns a collection of things, and ordered pointers to them elsewhere. Items stay their own types. Libraries are keyed and host-mounted. Placements only store what is pointed at and in what order.

Version **0.1.1**. Recording Studio dummy GitHub tag `v4.4.0`, Accessible `v0.14.0`, Orderable `v0.2.8`, Trashable `v0.7.0`, Metrics `v0.2.2`, Flatpack `v0.1.227`.

## What it does

- Opens a keyed library on first use (`library_for(parent, key: :default)`). People never create or title it. Read paths use `find_library`, which never creates.
- Keeps items as ordinary child recordings of that library. `Library.to(types:, keys:)` is enforced whenever an item is recorded into a library.
- Places ordered pointers under a holder (`place!`, `reorder!`, `remove!`). `place!` requires the actor can view the item and that the item lives in a live library. The picker lists library items only.
- Resolves those pointers for display, skipping trash, missing items, items outside a live library, other workspaces, and anything the actor cannot see. Anonymous visitors go through Accessible. Trusted system jobs should pass `unfiltered: true` on that resolve call. `configuration.unfiltered_access` remains as a process-wide fallback.
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
gem "recording_studio_library", github: "bowerbird-app/RecordingStudio_library", tag: "v0.1.1"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.14.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.2.8"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.7.0"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.227"
```

```bash
bin/rails generate recording_studio_library:install
bin/rails generate recording_studio_library:migrations
bin/rails db:migrate
bin/rails tailwindcss:build
```

Then opt a parent into `Library.to` and a holder into `Placeable.to`, and register an adapter per item type. Call `library_for` (the write path) before a library page or picker can find a library; `find_library` never creates one. Pin `@hotwired/turbo-rails` in the host importmap so the placements picker can load inside a navigable modal. Staff screens belong in Recording Studio Admin, not in this gem.

Adapters can implement `item_path` and `new_item_path` so hosts do not need to prepend `library_item_path_for` / `library_new_item_path_for`. Collection editors that save per-item fields should `PATCH` `recording_placements_path(holder)` — see the 0.1.1 changelog.

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

Template notes for how addon engines are structured live under `docs/gem_template/`. Product behaviour for this gem lives in `docs/LIBRARY.md`.
