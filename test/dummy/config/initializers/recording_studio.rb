# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  host_types = [
    "Workspace",
    "Folder",
    "Page",
    "Showcase",
    "RecordingStudioLibrary::Library",
    "RecordingStudioLibrary::Placement",
    "RecordingStudioLibrary::SampleItem"
  ]
  host_types << "RecordingStudioApi::AdminApi" if defined?(RecordingStudioApi)
  config.recordable_types = host_types

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Shown in the shared default layout title fallback.
  config.app_name = "Library Demo" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Hosts must set authorize_write before Recording Studio core 6.5.0.
  # Writes fail closed: missing authorize_write raises AuthorizationError;
  # missing actor raises ActorRequired. `actor.present?` is not a write policy.
  # Access grant/bootstrap writes go through Accessible's AccessCreationContext
  # (same path as grant_access / bootstrap_owner_access!), not a logged-in check.
  config.authorize_write = lambda { |actor:, root_recording:, recording: nil, parent_recording: nil, recordable: nil, **|
    next false unless defined?(RecordingStudioAccessible)
    next false unless actor.respond_to?(:persisted?) && actor.persisted?

    target = recording || parent_recording || root_recording
    next false unless target
    next true if defined?(RecordingStudio::Access) &&
                 recordable.is_a?(RecordingStudio::Access) &&
                 RecordingStudioAccessible::AccessCreationContext.allowed?

    api_engine_recordable = defined?(RecordingStudioApi) &&
                            recordable.class.name.to_s.start_with?("RecordingStudioApi::")
    next true if api_engine_recordable && RecordingStudioAccessible::AccessCreationContext.allowed?

    RecordingStudioAccessible.authorized?(
      actor: actor,
      recording: target,
      role: :edit
    )
  }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
