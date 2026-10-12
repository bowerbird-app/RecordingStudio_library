# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Placeable
      def self.to(**options)
        RecordingStudio::Capabilities.include_for(:placeable, **options)
      end

      module RecordingMethods
        include RecordingStudio::Capability if defined?(RecordingStudio::Capability)

        def place!(item, actor: nil)
          assert_placeable_capability!
          RecordingStudioLibrary.place!(self, item, actor: actor)
        end

        def place_new!(library:, type:, attrs: {}, actor: nil)
          assert_placeable_capability!
          RecordingStudioLibrary.place_new!(self, library: library, type: type, attrs: attrs, actor: actor)
        end

        def placements(include_trashed: false, actor: nil)
          assert_placeable_capability!
          RecordingStudioLibrary.resolve(self, include_trashed: include_trashed, actor: actor)
        end

        def reorder_placements!(ids, actor: nil)
          assert_placeable_capability!
          RecordingStudioLibrary.reorder!(self, ids, actor: actor)
        end

        def remove_placement!(placement, actor: nil)
          assert_placeable_capability!
          RecordingStudioLibrary.remove!(placement, holder: self, actor: actor)
        end

        private

        def assert_placeable_capability!
          return unless respond_to?(:assert_capability!, true)

          assert_capability!(:placeable, for_type: recordable_type)
        end
      end
    end
  end
end
