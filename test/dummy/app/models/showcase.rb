class Showcase < ApplicationRecord
  recording_studio_recordable label: "Showcase", root: false, allowed_parent_types: [ "Workspace" ]
  include RecordingStudio::Capabilities::Placeable.to(
    types: [ "RecordingStudioLibrary::SampleItem", "Page" ],
    libraries: [ :default ]
  )
  include RecordingStudio::Capabilities::Orderable.to if defined?(RecordingStudio::Capabilities::Orderable)
  include RecordingStudio::Capabilities::Trashable.to if defined?(RecordingStudio::Capabilities::Trashable)
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
end
