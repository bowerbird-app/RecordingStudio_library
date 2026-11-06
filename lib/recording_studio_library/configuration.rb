# frozen_string_literal: true

module RecordingStudioLibrary
  class Configuration
    ROLE_ALIASES = {
      viewer: :view,
      editor: :edit,
      viewing: :view,
      editing: :edit
    }.freeze

    attr_accessor :library_label,
                  :picker_libraries,
                  :place_label
    attr_reader :hooks, :auth_roles, :layout

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @layout = nil
      @auth_roles = default_auth_roles
      @library_label = default_library_label
      @picker_libraries = default_picker_libraries
      @place_label = default_place_label
    end

    def layout=(value)
      @layout = RecordingStudio::Layout.accept(legacy_layout(value))
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
        hooks_registered: hooks.registered_counts
      }
    end

    private

    def merge_value(key, value)
      key.to_sym == :auth_roles ? normalize_auth_roles(value) : value
    end

    def legacy_layout(value)
      return RecordingStudio::DEFAULT_LAYOUT if default_layout_value?(value)

      value
    end

    def default_layout_value?(value)
      return true if value.nil? || value == :default
      return false unless value.is_a?(String)

      normalized = value.strip
      normalized.empty? || normalized.casecmp("default").zero?
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
