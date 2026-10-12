# frozen_string_literal: true

module RecordingStudioLibrary
  module Adapters
    class Base
      attr_reader :recording

      def initialize(recording)
        @recording = recording
      end

      def recordable
        recording.try(:recordable)
      end

      def type_name
        recording.try(:recordable_type).to_s
      end

      def type_label
        declared = declared_type_label
        return declared if declared.present?

        type_name.demodulize.presence || I18n.t("recording_studio.library.items.fallback_type")
      end

      def icon
        :square
      end

      def title
        recordable_value(:title) || recordable_value(:name) || type_label
      end

      def search_text
        [title, recordable_value(:summary), recordable_value(:body), type_label].compact.join(" ")
      end

      def thumbnail(view)
        view.tag.div(class: "flex h-full w-full min-h-24 items-center justify-center bg-(--surface-muted-background-color)") do
          view.tag.span(title.to_s.first.to_s.upcase.presence || "?", class: "text-2xl font-semibold")
        end
      end

      def preview(view)
        view.tag.div(class: "flex h-12 w-12 items-center justify-center rounded-lg bg-(--surface-muted-background-color)") do
          view.tag.span(title.to_s.first.to_s.upcase.presence || "?", class: "text-sm font-semibold")
        end
      end

      def full_view(view)
        view.render(
          FlatPack::PageTitle::Component.new(title: title, subtitle: type_label, variant: :h2)
        )
      end

      def create_fields(view, form)
        edit_fields(view, form)
      end

      def edit_fields(view, form)
        view.render(
          FlatPack::TextInput::Component.new(
            form: form,
            name: :title,
            label: I18n.t("recording_studio.library.items.title_label"),
            value: title
          )
        )
      end

      def matches?(query)
        return true if query.blank?

        search_text.downcase.include?(query.to_s.downcase)
      end

      private

      def recordable_value(method_name)
        return unless recordable.respond_to?(method_name)

        recordable.public_send(method_name).to_s.strip.presence
      end

      def declared_type_label
        return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:recordable_declaration_for)

        RecordingStudio.recordable_declaration_for(type_name)&.label
      rescue StandardError
        nil
      end
    end
  end
end
