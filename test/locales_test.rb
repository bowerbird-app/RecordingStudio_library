# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  def test_english_locale_covers_library_copy
    locale = YAML.safe_load_file(File.expand_path("../config/locales/en.yml", __dir__))
    library = locale.fetch("en").fetch("recording_studio").fetch("library")

    refute_empty library.fetch("library").fetch("title")
    refute_empty library.fetch("picker").fetch("title")
    refute_empty library.fetch("placements").fetch("title")
    refute_empty library.fetch("errors").fetch("different_workspace")
    refute_empty library.fetch("confirm").fetch("trash_in_use")
  end

  def test_views_do_not_hardcode_user_facing_copy
    Dir[File.expand_path("../app/views/**/*.erb", __dir__)].each do |path|
      source = File.read(path)
      refute_match(/Nothing in this library yet/, source, path)
      refute_match(/Choose from library/, source, path)
    end
  end
end
