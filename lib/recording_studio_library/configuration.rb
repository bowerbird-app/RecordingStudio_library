# frozen_string_literal: true

module RecordingStudioLibrary
  class Configuration
    ROLE_ALIASES = {
      viewer: :view,
      editor: :edit,
      viewing: :view,
      editing: :edit
    }.freeze

    attr_accessor :layout,
                  :authorize_with,
                  :library_label,
                  :picker_libraries,
                  :place_label,
                  :unfiltered_access
    attr_reader :hooks, :auth_roles

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @layout = :default
      @auth_roles = default_auth_roles
      @authorize_with = nil
      @library_label = default_library_label
      @picker_libraries = default_picker_libraries
      @place_label = default_place_label
      @unfiltered_access = false
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, merge_value(key, value)) if respond_to?(setter)
      end
    end

    def normalize_role(role)
      normalized = role.to_s.downcase.to_sym
      ROLE_ALIASES.fetch(normalized, normalized)
    end

    def normalize_auth_roles(roles)
      roles.to_h.transform_keys(&:to_sym).transform_values { |role| normalize_role(role) }
    end

    def auth_roles=(roles)
      @auth_roles = normalize_auth_roles(roles)
    end

    def to_h
      {
        layout: layout,
        auth_roles: auth_roles,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    private

    def merge_value(key, value)
      key.to_sym == :auth_roles ? normalize_auth_roles(value) : value
    end

    def default_auth_roles
      normalize_auth_roles(
        view: :viewer,
        upload: :editor,
        revise: :editor,
        remove: :admin,
        restore: :admin
      )
    end

    def default_library_label
      lambda { |key|
        I18n.t(
          "recording_studio.library.keys.#{key}",
          default: RecordingStudioLibrary::Services::LibraryQuery.humanized_key(key)
        )
      }
    end

    def default_picker_libraries
      lambda { |parent_recording|
        Array(RecordingStudioLibrary.find_library(parent_recording)).compact
      }
    end

    def default_place_label
      ->(parent_recording) { RecordingStudioLibrary::Placements.fallback_place_label(parent_recording) }
    end
  end
end
