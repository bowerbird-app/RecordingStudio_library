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

  def grant_role!(user, recording, role, manager:)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: user,
      role: role,
      manager_actor: manager
    )
    raise result.error if result.respond_to?(:failure?) && result.failure?

    result
  end

  def with_replaced_singleton(target, name, replacement)
    original = target.method(name)
    target.define_singleton_method(name, &replacement)
    yield
  ensure
    target.define_singleton_method(name) do |*args, **kwargs, &block|
      original.call(*args, **kwargs, &block)
    end
  end

  def with_replaced_instance_method(mod, name, replacement)
    original = mod.instance_method(name)
    mod.define_method(name, &replacement)
    yield
  ensure
    mod.define_method(name, original)
  end
end

class ActiveSupport::TestCase
  include LibraryTestHelpers
end

class ActionDispatch::IntegrationTest
  include LibraryTestHelpers
end
