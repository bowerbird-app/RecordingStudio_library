class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder", "RecordingStudioLibrary::Library" ]
  include RecordingStudio::Capabilities::Trashable.to if defined?(RecordingStudio::Capabilities::Trashable)
end
