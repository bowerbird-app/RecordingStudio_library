class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  include RecordingStudio::Capabilities::Library.to(
    types: [ "RecordingStudioLibrary::SampleItem", "Page" ],
    keys: [ :default ]
  )
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
end
