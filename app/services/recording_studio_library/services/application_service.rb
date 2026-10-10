# frozen_string_literal: true

require_relative "placement_guards"

module RecordingStudioLibrary
  module Services
    class ApplicationService < RecordingStudio::Services::BaseService
      HANDLED_EXCEPTIONS = [
        ArgumentError,
        ActiveRecord::ActiveRecordError,
        RecordingStudioLibrary::Error
      ].freeze

      def call(&)
        super
      rescue *HANDLED_EXCEPTIONS => e
        failure(e)
      end

      private

      def require_recording_studio!
        return if defined?(RecordingStudio)

        raise RecordingStudioLibrary::DependencyUnavailableError, "RecordingStudio must be loaded"
      end

      def resolve_actor(explicit_actor)
        explicit_actor || (defined?(Current) && Current.respond_to?(:actor) ? Current.actor : nil)
      end

      def root_recording_for(recording)
        return recording unless recording.respond_to?(:root_recording)

        recording.root_recording || recording
      end

      def deny!(key)
        raise ArgumentError, I18n.t("recording_studio.library.errors.#{key}")
      end

      include PlacementGuards
    end
  end
end
