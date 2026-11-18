# Upgrading Recording Studio Library

## 0.5.x to 0.6.0

Pin `v0.6.0`. Compare [v0.5.0...v0.6.0](https://github.com/bowerbird-app/RecordingStudio_library/compare/v0.5.0...v0.6.0). The gemspec floor is now `recording_studio` `~> 7.7` (GitHub tag `v7.7.1`), not `>= 6.5.0`.

Hosts MUST run the Recording Studio 7.4, 7.5, and 7.7 migrations before using this release: `20261116230000_add_recording_studio_recordings_root_type_creation_index`, `20261117120000_enforce_recording_studio_recording_root_invariant`, and `20261117200000_replace_recording_studio_recordings_root_index`. Install them from the Recording Studio engine. This gem's dummy does not ship them. Hosts that have not applied Recording Studio 6.9 MUST also run `20261114090000_add_root_recording_id_to_recording_studio_events`. Hosts that have not applied Trashable `purge_at` MUST add that column on `recording_studio_recordings` (Trashable migration `add_purge_at_to_recording_studio_recordings`).

`RecordingStudio.root_recording_for` only finds a root. Call sites that used to create one MUST call `RecordingStudio.create_root_recording!(recordable, actor:)`. `config.authorize_write` MUST allow creating the root recordable when `root_recording` is nil. A persisted actor may create that root recordable (in the dummy, a Workspace). Later writes still need an Accessible role on the root.

Recording Studio API 1.15+ declares `RecordingStudioApi::AdminApi` only when `admin_root_recordable_type_names` names a loaded admin root type. Remove `RecordingStudioApi::AdminApi` from `config.recordable_types` unless that admin root type is configured. Hosts that mount Admin 2.15+ MUST set `RecordingStudioAccessible` `config.admin_root_resolver` to the kept AdminRoot `"Admin"` recording (create that root in seeds when admin screens are mounted).

The API install template has included `config/recording_studio_api.yml` since API `0.1.1`. API `1.12.0` raises at boot when that file is missing or invalid. The API client owner migration `20261117000024_add_owner_to_recording_studio_api_api_clients` arrived in API `1.4.0`. Apply it when `recording_studio_api_api_clients` has no `owner_type` / `owner_id`. The dummy adds both so it boots on the API `v1.16.0` pin.

Lockfiles move `tailwind_merge` from `0.16.0` to `1.5.6` because FlatPack `v0.1.378` requires `>= 1.5.2`. `view_component` moves from `4.23.0` to `4.24.0` as a lock-only bump. The engine has no TailwindMerge call sites. Hosts that call TailwindMerge directly should check the 1.x API.

Library engine behavior is unchanged in this release. The breaking steps above come from the Recording Studio 7.7, API 1.15+, and Admin 2.15+ floors.
