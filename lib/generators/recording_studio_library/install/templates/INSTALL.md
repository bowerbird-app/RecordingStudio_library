RecordingStudioLibrary install complete.

Next steps:

1. Review config/initializers/recording_studio_library.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_library.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_library:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
4a. Hosts MUST run the Recording Studio 7.4, 7.5, and 7.7 migrations (`20261116230000_add_recording_studio_recordings_root_type_creation_index`, `20261117120000_enforce_recording_studio_recording_root_invariant`, `20261117200000_replace_recording_studio_recordings_root_index`). This gem does not copy them. Hosts that have not applied Recording Studio 6.9 MUST also run `20261114090000_add_root_recording_id_to_recording_studio_events`. Hosts MUST also add Trashable `purge_at` on `recording_studio_recordings`. Create roots with `RecordingStudio.create_root_recording!`. `root_recording_for` only finds. Set Accessible `admin_root_resolver` when Admin is mounted, and leave `RecordingStudioApi::AdminApi` out of `recordable_types` unless an admin root type is configured.
5. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
6. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
7. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
8. Pin `@hotwired/turbo-rails` (to `turbo.min.js`) and import it in the host application.js so the placements picker can load inside a navigable modal.