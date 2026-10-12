# frozen_string_literal: true

module RecordingStudioLibrary
  class Placement < ApplicationRecord
    self.table_name = "recording_studio_library_placements"

    if respond_to?(:recording_studio_recordable)
      recording_studio_recordable(
        label: "Placed item",
        plural_label: "Placed items",
        root: false
      )
    end

    include RecordingStudio::Capabilities::Trashable.to if defined?(RecordingStudio::Capabilities::Trashable)

    validates :item_recording_id, presence: true

    def title
      adapter = begin
        item = RecordingStudio::Recording.find_by(id: item_recording_id)
        RecordingStudioLibrary.adapter_for(item).title if item
      rescue StandardError
        nil
      end

      adapter.presence || I18n.t("recording_studio.library.placements.item_fallback")
    end
  end
end
