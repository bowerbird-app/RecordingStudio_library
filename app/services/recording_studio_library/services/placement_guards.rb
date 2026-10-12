# frozen_string_literal: true

module RecordingStudioLibrary
  module Services
    module PlacementGuards
      private

      def assert_placement_enabled!(recording)
        RecordingStudioLibrary::Authorization.assert_placement_enabled!(recording: recording)
      end

      def authorize_placement!(action:, actor:, recording:)
        RecordingStudioLibrary::Authorization.authorize_placement!(
          action: action,
          actor: actor,
          recording: recording
        )
      end

      def assert_same_root!(parent, item)
        return if same_root?(parent, item)

        raise ArgumentError, I18n.t("recording_studio.library.errors.different_workspace")
      end

      def same_root?(left, right)
        left_root = root_id_for(left)
        right_root = root_id_for(right)
        left_root.present? && left_root == right_root
      end

      def assert_placeable_type!(parent, item_or_type)
        type_name = item_or_type.respond_to?(:recordable_type) ? item_or_type.recordable_type.to_s : item_or_type.to_s
        allowed = allowed_item_types_for(parent)
        return if allowed.empty?
        return if allowed.include?(type_name)

        raise ArgumentError, I18n.t("recording_studio.library.errors.type_not_allowed")
      end

      def assert_library_allows_type!(library, type_name)
        allowed = LibraryQuery.allowed_item_types_for(library)
        return if allowed.empty?
        return if allowed.include?(type_name.to_s)

        raise ArgumentError, I18n.t("recording_studio.library.errors.type_not_allowed")
      end

      def assert_library_key_allowed!(library)
        parent = library.try(:parent_recording)
        allowed = LibraryQuery.allowed_keys_for(parent)
        return if allowed.empty?
        return if allowed.include?(LibraryQuery.key_for(library))

        raise ArgumentError, I18n.t("recording_studio.library.errors.key_not_allowed")
      end

      def assert_adapter_registered!(type_name)
        return if RecordingStudioLibrary::Adapters.registered?(type_name)

        raise ArgumentError, I18n.t("recording_studio.library.errors.adapter_not_registered")
      end

      def assert_item_visible!(item, actor)
        return if RecordingStudioLibrary::Authorization.visible?(actor: actor, recording: item)

        raise ArgumentError, I18n.t("recording_studio.library.errors.item_not_visible")
      end

      def assert_library_allowed!(parent, item)
        library = library_for_item(item)
        deny!(:item_not_in_library) unless live_library?(library)
        raise ArgumentError, I18n.t("recording_studio.library.errors.different_workspace") unless same_root?(parent, library)

        allowed_keys = allowed_library_keys_for(parent)
        return if allowed_keys.empty?
        return if allowed_keys.include?(LibraryQuery.key_for(library))

        raise ArgumentError, I18n.t("recording_studio.library.errors.library_not_allowed")
      end

      def live_library?(library)
        library.present? && LibraryQuery.live?(library)
      end

      def live_library_item?(item)
        live_library?(library_for_item(item))
      end

      def library_for_item(item)
        parent = item.try(:parent_recording)
        return parent if Placements.library_recording?(parent)

        id = item.try(:parent_recording_id)
        return if id.blank?

        found = RecordingStudio::Recording.find_by(id: id)
        found if Placements.library_recording?(found)
      rescue StandardError
        nil
      end

      def allowed_item_types_for(recording)
        options = RecordingStudioLibrary::Authorization.capability_options_for(:placeable, recording)
        Array(options[:types] || options["types"]).map(&:to_s)
      end

      def allowed_library_keys_for(recording)
        options = RecordingStudioLibrary::Authorization.capability_options_for(:placeable, recording)
        Array(options[:libraries] || options["libraries"]).map { |key| LibraryQuery.normalize_key(key) }
      rescue ArgumentError
        []
      end

      def root_id_for(recording)
        return if recording.blank?

        if recording.respond_to?(:root_recording_id) && recording.root_recording_id.present?
          recording.root_recording_id.to_s
        elsif recording.respond_to?(:id)
          recording.id.to_s
        end
      end
    end
  end
end
