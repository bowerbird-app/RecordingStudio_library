# frozen_string_literal: true

module RecordingStudioLibrary
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudioLibrary::Authorization::NotAuthorizedError, RecordingStudio::AuthorizationError => e
        raise ::RecordingStudioApi::AuthorizationError, e.message
      rescue ActiveRecord::RecordNotFound => e
        raise ::RecordingStudioApi::NotFoundError, e.message
      rescue ArgumentError => e
        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
