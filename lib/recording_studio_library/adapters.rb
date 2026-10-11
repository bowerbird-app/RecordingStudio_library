# frozen_string_literal: true

module RecordingStudioLibrary
  module Adapters
    class << self
      def registry
        @registry ||= {}
      end

      def register(type, adapter_class)
        registry[type.to_s] = adapter_class
      end

      def for(recording_or_type)
        type = if recording_or_type.respond_to?(:recordable_type)
                 recording_or_type.recordable_type
               else
                 recording_or_type.to_s
               end
        registry[type] || Base
      end

      def wrap(recording)
        self.for(recording).new(recording)
      end

      def registered?(type)
        registry.key?(type.to_s)
      end

      def registered_types
        registry.keys
      end
    end
  end
end
