# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 extracts Object#stub into the minitest-mock gem. The dummy
  # bundle does not load that gem; only the gem suite stubs methods.
end
require "rails"
require "active_record"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_library"

Dir[File.expand_path("../app/services/**/*.rb", __dir__)].each { |path| require path }

I18n.load_path << File.expand_path("../config/locales/en.yml", __dir__)
I18n.backend.load_translations
I18n.default_locale = :en
