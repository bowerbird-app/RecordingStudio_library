# frozen_string_literal: true

RecordingStudioLibrary.configure do |config|
  config.layout = :default
end

RecordingStudioLibrary.register_adapter("Page", RecordingStudioLibrary::Adapters::Dummy)
