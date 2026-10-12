# frozen_string_literal: true

module RecordingStudioLibrary
  module Placements
    LIBRARY_TYPE = "RecordingStudioLibrary::Library"
    PLACEMENT_TYPE = "RecordingStudioLibrary::Placement"

    Resolved = Struct.new(:placement_recording, :item_recording, :item, :adapter, keyword_init: true)
    Usage = Struct.new(:placement_recording, :parent_recording, :label, keyword_init: true)

    class << self
      def resolve(parent_recording, include_trashed: false, actor: nil, unfiltered: false)
        RecordingStudioLibrary::Services::ResolvePlacements.call(
          parent_recording: parent_recording,
          include_trashed: include_trashed,
          actor: actor,
          unfiltered: unfiltered
        ).value || []
      end

      def usage_for(item_recording)
        RecordingStudioLibrary::Services::PlacementUsage.call(item_recording: item_recording).value || []
      end

      def usage_for_library(library_recording)
        RecordingStudioLibrary::Services::LibraryUsage.call(library_recording: library_recording).value || []
      end

      def purge_for(item_recording)
        RecordingStudioLibrary::Services::PurgePlacements.call(item_recording: item_recording).value
      end

      def purge_library(library_recording)
        RecordingStudioLibrary::Services::PurgeLibraryPlacements.call(library_recording: library_recording).value
      end

      def picker_libraries_for(parent_recording)
        resolver = RecordingStudioLibrary.configuration.picker_libraries
        Array(resolver.call(parent_recording)).select { |library| RecordingStudioLibrary::Services::LibraryQuery.live?(library) }
      rescue StandardError
        []
      end

      def library_title(library_recording)
        RecordingStudioLibrary::Services::LibraryQuery.title_for(library_recording)
      end

      def library_recording?(recording)
        recording.respond_to?(:recordable_type) && recording.recordable_type == LIBRARY_TYPE
      end

      def placement_recording?(recording)
        recording.respond_to?(:recordable_type) && recording.recordable_type == PLACEMENT_TYPE
      end

      def place_label(parent_recording)
        resolver = RecordingStudioLibrary.configuration.place_label
        resolver.call(parent_recording).to_s.strip.presence || fallback_place_label(parent_recording)
      end

      def fallback_place_label(parent_recording)
        recordable = parent_recording.try(:recordable)
        %i[title name].each do |method_name|
          next unless recordable.respond_to?(method_name)

          value = recordable.public_send(method_name).to_s.strip
          return value if value.present?
        end

        declared_label(parent_recording) || parent_recording.try(:recordable_type).to_s.demodulize.presence ||
          I18n.t("recording_studio.library.untitled")
      end

      def declared_label(parent_recording)
        return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:recordable_declaration_for)

        type = parent_recording.try(:recordable_type)
        return if type.blank?

        RecordingStudio.recordable_declaration_for(type)&.label
      rescue StandardError
        nil
      end
    end
  end
end
