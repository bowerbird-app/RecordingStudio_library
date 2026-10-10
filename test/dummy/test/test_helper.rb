# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module LibraryTestHelpers
  def grant_admin!(user, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user)
    raise result.error if result.respond_to?(:failure?) && result.failure?

    result
  end
end

class ActiveSupport::TestCase
  include LibraryTestHelpers
end

class ActionDispatch::IntegrationTest
  include LibraryTestHelpers
end
