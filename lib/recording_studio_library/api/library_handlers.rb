# frozen_string_literal: true

require_relative "errors"
require_relative "lookup"

module RecordingStudioLibrary
  module Api
    module LibraryHandlers
      class OpenLibrary
        def self.call(context)
          Errors.wrap do
            RecordingStudioLibrary::Authorization.authorize_library!(action: :upload, actor: context.actor, recording: context.recording)
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
            RecordingStudioLibrary::Authorization.authorize_library!(action: :view, actor: context.actor, recording: context.recording)
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
            RecordingStudioLibrary::Authorization.authorize_library!(action: :view, actor: context.actor, recording: context.recording)
            RecordingStudioLibrary.libraries_for(context.recording)
          end
        end
      end
    end
  end
end
