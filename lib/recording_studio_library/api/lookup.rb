# frozen_string_literal: true

module RecordingStudioLibrary
  module Api
    module Lookup
      module_function

      def library_key(params)
        params[:key].presence || :default
      end

      def recording!(id)
        found = RecordingStudio::Recording.find_by(id: id)
        raise ::RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if found.nil?

        found
      end
    end
  end
end
