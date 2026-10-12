# frozen_string_literal: true

module RecordingStudioLibrary
  module Purge
    extend ActiveSupport::Concern

    included do
      before_destroy :recording_studio_library_purge_placements, prepend: true
    end

    def recording_studio_library_purge_placements
      case recordable_type
      when Placements::LIBRARY_TYPE
        RecordingStudioLibrary::Placements.purge_library(self)
      when Placements::PLACEMENT_TYPE
        nil
      else
        RecordingStudioLibrary::Placements.purge_for(self)
      end
    end
  end
end
