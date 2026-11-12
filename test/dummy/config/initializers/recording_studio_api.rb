# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.documentation_enabled = true
  config.documentation_access = :public
  config.openapi_title = "Library API"
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
  config.admin_root_recordable_type_names = []
end

RecordingStudioApi.register_recordable_type_api(
  "Workspace",
  operations: %i[show],
  auto_capability_actions: false,
  capability_actions: %i[library_open_library library_find_library library_libraries_for],
  serializer: ->(workspace, **) { { name: workspace.name } },
  output_keys: %i[name]
)

RecordingStudioApi.register_recordable_type_api(
  "Showcase",
  operations: %i[show],
  auto_capability_actions: false,
  capability_actions: %i[library_place library_place_new library_reorder_placements library_remove_placement library_resolve_placements],
  serializer: ->(showcase, **) { { title: showcase.title } },
  output_keys: %i[title]
)
