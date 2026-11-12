# frozen_string_literal: true

module RecordingStudioLibrary
  module Api
    module Serializer
      module_function

      def recording(result)
        ::RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(result)
      end

      def libraries(result)
        { records: Array(result).map { |library| recording(library) } }
      end

      def placements(result)
        {
          placements: Array(result).map do |entry|
            {
              id: entry.placement_recording.id,
              item_id: entry.item_recording.id,
              type: entry.placement_recording.recordable_type
            }
          end
        }
      end
    end
  end
end
