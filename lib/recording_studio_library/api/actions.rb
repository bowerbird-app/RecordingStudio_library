# frozen_string_literal: true

require_relative "catalog"

module RecordingStudioLibrary
  module Api
    module Actions
      module_function

      def register!(api)
        CATALOG.each { |definition| register_action(api, definition) }
      end

      def register_action(api, definition)
        name = definition.fetch(:name)
        return if ::RecordingStudioApi.capability_action(name, api:)

        ::RecordingStudioApi.register_capability_action(name, api:, **payload(definition))
      end

      def payload(definition)
        title = definition.fetch(:title)
        definition.slice(:capability, :required_role, :handler, :serializer).merge(
          version: "1.0.0",
          http_verb: :post,
          input_contract: contract(definition[:fields]),
          openapi: { title:, summary: title, description: definition.fetch(:description) }
        )
      end

      def contract(fields)
        return if fields.blank?

        { reject_unknown: false, fields: fields }
      end
    end
  end
end
