# frozen_string_literal: true

module RecordingStudioLibrary
  class SampleItem < ApplicationRecord
    self.table_name = "recording_studio_library_sample_items"

    if respond_to?(:recording_studio_recordable)
      recording_studio_recordable(
        label: "Sample",
        plural_label: "Samples",
        root: false,
        allowed_parent_types: ["RecordingStudioLibrary::Library"]
      )
    end

    include RecordingStudio::Capabilities::Trashable.to if defined?(RecordingStudio::Capabilities::Trashable)

    validates :title, presence: true

    def title
      self[:title]
    end
  end
end
