# frozen_string_literal: true

require_relative "library_handlers"
require_relative "serializer"

module RecordingStudioLibrary
  module Api
    module LibraryCatalog
      ENTRIES = [
        {
          name: :library_open_library,
          capability: :library,
          required_role: :edit,
          handler: LibraryHandlers::OpenLibrary,
          serializer: Serializer.method(:recording),
          title: "Library - Open",
          description: "Finds or creates the keyed library under this parent. This is the " \
                       "write path. The caller needs Library upload on the parent. Use " \
                       "library_find_library when you only want to look up an existing library.",
          fields: {
            key: { type: :string, required: false, allow_blank: false }
          }
        },
        {
          name: :library_find_library,
          capability: :library,
          required_role: :view,
          handler: LibraryHandlers::FindLibrary,
          serializer: Serializer.method(:recording),
          title: "Library - Find",
          description: "Looks up a keyed library under this parent without creating one. " \
                       "The caller needs Library view on the parent. Missing libraries are 404.",
          fields: {
            key: { type: :string, required: false, allow_blank: false }
          }
        },
        {
          name: :library_libraries_for,
          capability: :library,
          required_role: :view,
          handler: LibraryHandlers::LibrariesFor,
          serializer: Serializer.method(:libraries),
          title: "Library - List",
          description: "Lists live libraries under this parent. The caller needs Library " \
                       "view on the parent. This never creates a library."
        }
      ].freeze
    end
  end
end
