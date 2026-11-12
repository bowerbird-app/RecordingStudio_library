# frozen_string_literal: true

require_relative "api/actions"

module RecordingStudioLibrary
  module Api
    module_function

    def register!
      return unless defined?(::RecordingStudioApi)

      ::RecordingStudioApi.configuration.each_api do |api|
        Actions.register!(api.name)
      end
    end
  end
end
