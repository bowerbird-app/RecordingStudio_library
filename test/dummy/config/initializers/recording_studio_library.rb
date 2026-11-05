# frozen_string_literal: true

RecordingStudioLibrary.configure do |config|
  # nil uses RecordingStudio.configuration.layout, then recording_studio/default_layout.
end

RecordingStudioLibrary.register_adapter("Page", RecordingStudioLibrary::Adapters::Dummy)
