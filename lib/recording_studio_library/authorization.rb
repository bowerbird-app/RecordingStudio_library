# frozen_string_literal: true

module RecordingStudioLibrary
  module Authorization
    class NotAuthorizedError < RecordingStudioLibrary::Error; end
    class CapabilityNotEnabledError < NotAuthorizedError; end

    class << self
      def authorize_library!(action:, actor:, recording:)
        assert_library_enabled!(recording: recording)
        return true if library_allowed?(action: action, actor: actor, recording: recording)

        owner_name = library_owner_for(recording)&.recordable_type || recording.class.name
        raise NotAuthorizedError, I18n.t("recording_studio.library.errors.not_authorized_library", action: action, owner: owner_name)
      end

      def library_allowed?(action:, actor:, recording:)
        return false unless library_enabled?(recording: recording)

        allowed?(action: action, actor: actor, recording: recording)
      end

      def library_enabled?(recording:)
        owner = library_owner_for(recording)
        capability_enabled?(:library, recording: owner)
      end

      def assert_library_enabled!(recording:)
        return if library_enabled?(recording: recording)

        owner_name = library_owner_for(recording)&.recordable_type || recording.class.name
        raise CapabilityNotEnabledError, I18n.t("recording_studio.library.errors.library_not_enabled", owner: owner_name)
      end

      def authorize_placement!(action:, actor:, recording:)
        assert_placement_enabled!(recording: recording)
        return true if placement_allowed?(action: action, actor: actor, recording: recording)

        raise NotAuthorizedError, I18n.t(
          "recording_studio.library.errors.not_authorized_placement",
          action: action,
          owner: recording&.recordable_type || recording.class.name
        )
      end

      def placement_allowed?(action:, actor:, recording:)
        return false unless placement_enabled?(recording: recording)

        allowed?(action: action, actor: actor, recording: recording)
      end

      def placement_enabled?(recording:)
        capability_enabled?(:placeable, recording: recording)
      end

      def assert_placement_enabled!(recording:)
        return if placement_enabled?(recording: recording)

        raise CapabilityNotEnabledError, I18n.t(
          "recording_studio.library.errors.placement_not_enabled",
          owner: recording&.recordable_type || recording.class.name
        )
      end

      def visible?(actor:, recording:)
        return true if actor.blank? && !accessible_loaded?
        return true unless accessible_loaded?

        RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: :view)
      rescue StandardError
        false
      end

      def library_owner_for(recording)
        return recording.parent_recording if Placements.library_recording?(recording) && recording.respond_to?(:parent_recording)

        recording
      end

      def capability_options_for(capability, recording)
        type = recording.try(:recordable_type)
        return {} if type.blank? || !defined?(RecordingStudio)

        RecordingStudio.capability_options(capability, for: type) ||
          RecordingStudio.capability_options(capability, for_type: type) ||
          {}
      rescue StandardError
        {}
      end

      private

      def allowed?(action:, actor:, recording:)
        role = required_role_for(action)
        return false if role.blank?

        adapter = RecordingStudioLibrary.configuration.authorize_with
        return !!adapter.call(action: action, actor: actor, recording: recording, role: role) if adapter.respond_to?(:call)
        return true unless accessible_loaded?

        RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: role)
      end

      def required_role_for(action)
        RecordingStudioLibrary.configuration.normalize_role(
          RecordingStudioLibrary.configuration.auth_roles[action.to_sym]
        )
      end

      def capability_enabled?(name, recording:)
        type = recording.try(:recordable_type)
        return false if type.blank? || !defined?(RecordingStudio)

        if RecordingStudio.respond_to?(:configuration) && RecordingStudio.configuration.respond_to?(:capability_enabled?)
          RecordingStudio.configuration.capability_enabled?(name, for_type: type)
        else
          RecordingStudio.respond_to?(:capability_enabled?) &&
            RecordingStudio.capability_enabled?(name, for: type)
        end
      rescue StandardError
        false
      end

      def accessible_loaded?
        defined?(RecordingStudioAccessible::Authorization)
      end
    end
  end
end
