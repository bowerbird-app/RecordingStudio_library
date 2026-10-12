# frozen_string_literal: true

module RecordingStudioLibrary
  module Adapters
    # Built-in adapter for the gem's sample item and any recordable that
    # exposes title / summary / accent. Ships so the gem is usable without
    # Attachable or Video.
    class Dummy < Base
      ACCENTS = {
        "coral" => "#e07a5f",
        "sage" => "#81b29a",
        "ink" => "#3d405b",
        "sand" => "#f2cc8f",
        "sky" => "#4d9de0"
      }.freeze

      def icon
        :sparkles
      end

      def type_label
        return super unless type_name == "RecordingStudioLibrary::SampleItem"

        I18n.t("recording_studio.library.sample_item.type")
      end

      def title
        recordable_value(:title) || super
      end

      def search_text
        [title, summary, accent_name, type_label].compact.join(" ")
      end

      def preview(view)
        color_swatch(view, size_class: "h-12 w-12", text_class: "text-sm")
      end

      def thumbnail(view)
        color_swatch(view, size_class: "h-full w-full min-h-24", text_class: "text-2xl", rounded: false)
      end

      def full_view(view)
        view.safe_join(
          [
            color_swatch(view, size_class: "h-40 w-full", text_class: "text-4xl"),
            view.tag.p(summary, class: "mt-4 text-sm leading-6 text-(--surface-muted-content-color)")
          ]
        )
      end

      def edit_fields(view, form)
        view.safe_join(
          [
            view.render(
              FlatPack::TextInput::Component.new(
                name: field_name(form, :title),
                label: I18n.t("recording_studio.library.items.title_label"),
                value: title
              )
            ),
            view.render(
              FlatPack::TextArea::Component.new(
                name: field_name(form, :summary),
                label: I18n.t("recording_studio.library.items.summary_label"),
                value: summary,
                rows: 3
              )
            ),
            view.render(
              FlatPack::Select::Component.new(
                name: field_name(form, :accent),
                label: I18n.t("recording_studio.library.items.accent_label"),
                options: ACCENTS.keys.map { |key| [key.capitalize, key] },
                value: accent_name
              )
            )
          ]
        )
      end

      def summary
        recordable_value(:summary)
      end

      def accent_name
        value = recordable_value(:accent).to_s.downcase
        ACCENTS.key?(value) ? value : "coral"
      end

      def accent_hex
        ACCENTS.fetch(accent_name)
      end

      def item_path(view, **options)
        return unless sample_item?

        library_routes(view).sample_item_path(recording, **options)
      end

      def new_item_path(view, library_recording, **options)
        return unless sample_item?

        library_routes(view).new_recording_sample_item_path(library_recording, **options)
      end

      def permitted_item_keys
        %i[title summary accent]
      end

      private

      def sample_item?
        type_name == "RecordingStudioLibrary::SampleItem"
      end

      def library_routes(view)
        if view.respond_to?(:library_engine_routes, true)
          view.library_engine_routes
        else
          RecordingStudioLibrary::Engine.routes.url_helpers
        end
      end

      def field_name(form, attribute)
        object_name = form.respond_to?(:object_name) ? form.object_name : nil
        return attribute if object_name.blank?

        "#{object_name}[#{attribute}]"
      end

      def color_swatch(view, size_class:, text_class:, rounded: true)
        rounding = rounded ? "rounded-lg" : nil
        view.tag.div(
          class: ["flex", size_class, "items-center", "justify-center", rounding, "text-white"].compact.join(" "),
          style: "background-color: #{accent_hex};",
          aria: { hidden: true }
        ) do
          view.tag.span(title.to_s.first.to_s.upcase.presence || "S", class: "#{text_class} font-semibold")
        end
      end
    end
  end
end
