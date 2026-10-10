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

  # Libraries offered in the picker for a holder recording.
  # config.picker_libraries = ->(parent_recording) { [RecordingStudioLibrary.library_for(parent_recording)] }

  # Label used when listing usages of an item.
  # config.place_label = ->(parent_recording) { parent_recording.recordable.try(:title) }
end
