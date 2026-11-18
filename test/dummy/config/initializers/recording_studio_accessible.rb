# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.access_actor_types += [ "RecordingStudioApi::ApiClient" ] if defined?(RecordingStudioApi)

  # Admin 2.15+ reads this for site-wide screens. The dummy does not mount
  # admin screens, so there is no AdminRoot recording to return. A nil root fails closed.
  config.admin_root_resolver = lambda do |context: nil|
    context
    nil
  end
end
