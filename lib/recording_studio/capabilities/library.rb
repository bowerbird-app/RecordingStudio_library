# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Library
      def self.to(**options)
        RecordingStudio::Capabilities.include_for(:library, **options)
      end

      module RecordingMethods
        include RecordingStudio::Capability if defined?(RecordingStudio::Capability)

        def library(key: :default, actor: nil)
          assert_library_capability!
          RecordingStudioLibrary.library_for(self, key: key, actor: actor)
        end

        def libraries
          assert_library_capability!
          RecordingStudioLibrary.libraries_for(self)
        end

        private

        def assert_library_capability!
          return unless respond_to?(:assert_capability!, true)

          assert_capability!(:library, for_type: recordable_type)
        end
      end
    end
  end
end
