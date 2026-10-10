# Dummy App

This Rails app exists to validate RecordingStudio Library in a real host application.

## What it covers

- Devise authentication with a seeded admin user
- A workspace that opts into `Library.to`
- A showcase that opts into `Placeable.to` and Orderable
- A seeded library of sample items rendered by the built-in dummy adapter
- Library list/grid, standalone picker, navigable-modal picker, and placements editor
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning

## Quick start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Sign in with `admin@admin.com` / `Password`.

## Useful routes

- `/` — demo home
- `/recording_studio_library/libraries/:id` — library
- `/recording_studio_library/recordings/:id/picker` — picker
- `/recording_studio_library/recordings/:id/placements` — placements editor
- `/users/sign_in` — Devise sign-in
- `/docs/*` — dummy-only starter pages
- `/up` — health check
