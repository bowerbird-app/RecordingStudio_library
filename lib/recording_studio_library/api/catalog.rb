# frozen_string_literal: true

require_relative "placement_catalog"
require_relative "library_catalog"

module RecordingStudioLibrary
  module Api
    CATALOG = (PlacementCatalog::ENTRIES + LibraryCatalog::ENTRIES).freeze
  end
end
