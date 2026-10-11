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

    def library_new_item_path_for(library_recording, **options)
      library_engine_routes.new_recording_sample_item_path(library_recording, **options)
    end

    def library_usage_confirm(usages)
      return t("recording_studio.library.confirm.trash") if usages.blank?

      labels = usages.map(&:label).uniq
      t("recording_studio.library.confirm.trash_in_use", places: labels.to_sentence)
    end

    def library_screen_page_nav(back_url:, title: nil, back_label: nil, anchor_url: nil, anchor_label: nil)
      back_label ||= t("recording_studio.library.navigation.back")
      anchor_label ||= t("recording_studio.library.navigation.return_to_source")
      return fill_host_library_page_nav(title:, back_url:, back_label:, anchor_url:, anchor_label:) if library_uses_host_page_nav?

      render FlatPack::PageNav::Component.new(
        back_icon: "arrow-left",
        back_label: back_label,
        anchor_url: anchor_url.presence || back_url,
        anchor_label: anchor_label
      )
    end

    def library_uses_host_page_nav?
      configured = RecordingStudioLibrary.configuration.layout
      (configured.blank? || configured.to_sym == :default) && respond_to?(:recording_studio_page_nav)
    end

    private

    def fill_host_library_page_nav(title:, back_url:, back_label:, anchor_url:, anchor_label:)
      recording_studio_page_nav(
        title: title,
        page_nav_back_url: back_url,
        page_nav_back_label: back_label,
        page_nav_anchor_url: anchor_url,
        page_nav_anchor_label: anchor_label
      )
      nil
    end

    def library_engine_routes
      if respond_to?(:recording_studio_library, true)
        recording_studio_library
      else
        RecordingStudioLibrary::Engine.routes.url_helpers
      end
    end
  end
end
