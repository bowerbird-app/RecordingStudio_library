# frozen_string_literal: true

module RecordingStudioLibrary
  module ApplicationHelper
    include FlatPack::ModalHelper if defined?(FlatPack::ModalHelper)

    def library_path_for(parent_or_library, key: :default, **options)
      if RecordingStudioLibrary::Placements.library_recording?(parent_or_library)
        library_engine_routes.library_path(parent_or_library, **options)
      else
        library_engine_routes.recording_library_path(parent_or_library, { key: key }.merge(options))
      end
    end

    def library_picker_path_for(holder, **options)
      library_engine_routes.recording_picker_path(holder, **options)
    end

    def library_placements_path_for(holder, **options)
      library_engine_routes.recording_placements_path(holder, **options)
    end

    def library_reorder_placements_path_for(holder, **options)
      library_engine_routes.recording_reorder_placements_path(holder, **options)
    end

    def library_title_for(library_recording)
      RecordingStudioLibrary::Placements.library_title(library_recording)
    end

    def library_item_path_for(item_recording, **options)
      return if item_recording.blank?
      return unless item_recording.recordable_type == RecordingStudioLibrary::SampleItem.name

      library_engine_routes.sample_item_path(item_recording, **options)
    end

    def library_new_item_path_for(library_recording, type: nil, **options)
      type_name = type.presence&.to_s || RecordingStudioLibrary::SampleItem.name
      return unless type_name == RecordingStudioLibrary::SampleItem.name

      library_engine_routes.new_recording_sample_item_path(library_recording, **options)
    end

    def library_type_label_for(type)
      recording = Struct.new(:recordable, :recordable_type).new(nil, type.to_s)
      RecordingStudioLibrary::Adapters.wrap(recording).type_label
    end

    def library_addable_types_for(library_recording)
      types = RecordingStudioLibrary::Services::LibraryQuery.allowed_item_types_for(library_recording)
      types = [RecordingStudioLibrary::SampleItem.name] if types.blank?
      types.select { |item_type| library_new_item_path_for(library_recording, type: item_type) }
    end

    def library_usage_confirm(usages)
      return t("recording_studio.library.confirm.trash") if usages.blank?

      labels = usages.map(&:label).uniq
      t("recording_studio.library.confirm.trash_in_use", places: labels.to_sentence)
    end

    def library_allowed?(action, recording)
      RecordingStudioLibrary::Authorization.library_allowed?(
        action: action,
        actor: current_library_actor,
        recording: recording
      )
    end

    def library_screen_page_nav(back_url:, title: nil, back_label: nil, anchor_url: nil, anchor_label: nil)
      content_for(:title, title) if title.present?
      back_label ||= t("recording_studio.library.navigation.back")
      anchor_label ||= t("recording_studio.library.navigation.return_to_source")
      kwargs = {
        round: true,
        style: :default,
        back_href: back_url,
        back_tooltip: back_label
      }
      if anchor_url.present?
        kwargs[:anchor_href] = anchor_url
        kwargs[:anchor_tooltip] = anchor_label
      end
      flat_pack_page_nav(**kwargs)
    end

    private

    def library_engine_routes
      if respond_to?(:recording_studio_library, true)
        recording_studio_library
      else
        RecordingStudioLibrary::Engine.routes.url_helpers
      end
    end
  end
end
