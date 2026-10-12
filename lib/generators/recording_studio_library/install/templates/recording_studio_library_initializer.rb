# frozen_string_literal: true

RecordingStudioLibrary.configure do |config|
  # Layout used by engine screens. `:default` uses Recording Studio's shared layout.
  # config.layout = :default

  # Override Accessible role mapping if the host uses different names.
  # config.auth_roles = { view: :viewer, upload: :editor, revise: :editor, remove: :admin, restore: :admin }

  # Optional host authorizer. Receives action:, actor:, recording:, role:.
  # config.authorize_with = ->(action:, actor:, recording:, role:) { true }

  # Label for a library key. Default reads i18n `recording_studio.library.keys.*`.
  # config.library_label = ->(key) { key.to_s.humanize }

  # Libraries offered in the picker for a holder recording. Default is find-only
  # (it never creates a library on GET).
  # config.picker_libraries = ->(parent_recording) { [RecordingStudioLibrary.find_library(parent_recording)] }

  # Label used when listing usages of an item.
  # config.place_label = ->(parent_recording) { parent_recording.recordable.try(:title) }

  # Opt-in unfiltered visibility for system jobs. Anonymous visitors otherwise
  # go through Accessible like everyone else.
  # config.unfiltered_access = false
end
