# frozen_string_literal: true

module RecordingStudioLibrary
  class Library < ApplicationRecord
    self.table_name = "recording_studio_libraries"

    KEY_PATTERN = /\A[a-z][a-z0-9_]*\z/

    if respond_to?(:recording_studio_recordable)
      recording_studio_recordable(
        label: "Library",
        plural_label: "Libraries",
        root: false
      )
    end

    include RecordingStudio::Capabilities::Trashable.to if defined?(RecordingStudio::Capabilities::Trashable)

    before_validation :normalize_key
    validates :key, presence: true, format: { with: KEY_PATTERN }

    def title
      RecordingStudioLibrary::Services::LibraryQuery.label_for_key(key)
    end

    private

    def normalize_key
      self.key = RecordingStudioLibrary::Services::LibraryQuery.normalize_key(key)
    rescue ArgumentError
      self.key = key.to_s.strip.downcase
    end
  end
end
