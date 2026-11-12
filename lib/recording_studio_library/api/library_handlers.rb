# frozen_string_literal: true

require_relative "errors"
require_relative "lookup"

module RecordingStudioLibrary
  module Api
    module LibraryHandlers
      class OpenLibrary
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioLibrary.library_for(
              context.recording,
              key: Lookup.library_key(context.params),
              actor: context.actor
            )
          end
        end
      end

      class FindLibrary
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :view)
            library = RecordingStudioLibrary.find_library(
              context.recording,
              key: Lookup.library_key(context.params)
            )
            raise ::RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if library.nil?

            library
          end
        end
      end

      class LibrariesFor
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :view)
            RecordingStudioLibrary.libraries_for(context.recording)
          end
        end
      end
    end
  end
end
