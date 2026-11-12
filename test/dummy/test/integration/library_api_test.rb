# frozen_string_literal: true

require "test_helper"

class LibraryApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    skip "recording_studio_api is not available" unless defined?(RecordingStudioApi)

    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    Current.actor = @owner
    @workspace = Workspace.create!(name: "API Library #{SecureRandom.hex(4)}")
    @root, @owner_access = owned_root(@workspace)
    @stranger = user("stranger")
    @other_workspace = Workspace.create!(name: "Other library #{SecureRandom.hex(4)}")
    @other_root, = owned_root(@other_workspace, actor: @stranger)
    @editor_access = grant!(@root, @editor, :edit)
    @viewer_access = grant!(@root, @viewer, :view)
    @editor_token, = token_for(@editor_access)
    @viewer_token, = token_for(@viewer_access)
    @admin_token, = token_for(@owner_access)
  end

  teardown { Current.actor = @previous_actor }

  test "library_open_library library_find_library and library_libraries_for go through library helpers" do
    missing = call(:post, "/workspaces/#{@root.id}/actions/library_find_library", @editor_token)
    assert_response :not_found, response.body

    opened = call(:post, "/workspaces/#{@root.id}/actions/library_open_library", @editor_token)
    assert_response :success, response.body
    library_id = opened.fetch("id")
    assert_equal library_id, RecordingStudioLibrary.find_library(@root).id

    found = call(:post, "/workspaces/#{@root.id}/actions/library_find_library", @editor_token)
    assert_response :success, response.body
    assert_equal library_id, found.fetch("id")

    listed = call(:post, "/workspaces/#{@root.id}/actions/library_libraries_for", @editor_token)
    assert_response :success, response.body
    assert_equal [library_id], listed.fetch("records").map { |row| row.fetch("id") }
  end

  test "library_place resolve reorder and remove go through placement helpers" do
    library = RecordingStudioLibrary.library_for(@root, actor: @owner)
    holder = showcase_recording("API gallery")
    item = sample_item(library, "API still")
    second = sample_item(library, "API later")

    placed = call(
      :post,
      "/showcases/#{holder.id}/actions/library_place",
      @editor_token,
      item_recording_id: item.id
    )
    assert_response :success, response.body
    first_id = placed.fetch("id")

    created = call(
      :post,
      "/showcases/#{holder.id}/actions/library_place_new",
      @editor_token,
      library_id: library.id,
      type: RecordingStudioLibrary::SampleItem.name,
      attrs: { title: "API made here", accent: "ink" }
    )
    assert_response :success, response.body
    assert_equal 2, RecordingStudioLibrary.resolve(holder, actor: @owner).size

    second_placement = RecordingStudioLibrary.place!(holder, second, actor: @owner)
    reordered = call(
      :post,
      "/showcases/#{holder.id}/actions/library_reorder_placements",
      @editor_token,
      ordered_recording_ids: [second_placement.id, first_id]
    )
    assert_response :success, response.body
    assert_equal holder.id, reordered.fetch("id")
    ordered_ids = RecordingStudioLibrary.resolve(holder, actor: @owner).map { |entry| entry.placement_recording.id }
    assert_equal [second_placement.id, first_id], ordered_ids.first(2)

    resolved = call(:post, "/showcases/#{holder.id}/actions/library_resolve_placements", @viewer_token)
    assert_response :success, response.body
    assert_includes resolved.fetch("placements").map { |row| row.fetch("item_id") }, item.id

    removed = call(
      :post,
      "/showcases/#{holder.id}/actions/library_remove_placement",
      @admin_token,
      placement_id: second_placement.id
    )
    assert_response :success, response.body
    remaining = RecordingStudioLibrary.resolve(holder, actor: @owner).map { |entry| entry.placement_recording.id }
    refute_includes remaining, second_placement.id
    assert_equal second_placement.id, removed.fetch("id")
  end

  test "lower roles are forbidden from writes" do
    library = RecordingStudioLibrary.library_for(@root, actor: @owner)
    holder = showcase_recording("Forbidden gallery")
    item = sample_item(library, "Forbidden still")
    placement = RecordingStudioLibrary.place!(holder, item, actor: @owner)

    call(:post, "/workspaces/#{@root.id}/actions/library_open_library", @viewer_token)
    assert_response :forbidden, response.body

    call(:post, "/showcases/#{holder.id}/actions/library_place", @viewer_token, item_recording_id: item.id)
    assert_response :forbidden, response.body

    call(
      :post,
      "/showcases/#{holder.id}/actions/library_place_new",
      @viewer_token,
      library_id: library.id,
      type: RecordingStudioLibrary::SampleItem.name,
      attrs: { title: "Nope" }
    )
    assert_response :forbidden, response.body

    call(
      :post,
      "/showcases/#{holder.id}/actions/library_reorder_placements",
      @viewer_token,
      ordered_recording_ids: [placement.id]
    )
    assert_response :forbidden, response.body

    call(
      :post,
      "/showcases/#{holder.id}/actions/library_remove_placement",
      @editor_token,
      placement_id: placement.id
    )
    assert_response :forbidden, response.body
  end

  test "view can read library and placements" do
    RecordingStudioLibrary.library_for(@root, actor: @owner)
    holder = showcase_recording("Readable gallery")

    call(:post, "/workspaces/#{@root.id}/actions/library_find_library", @viewer_token)
    assert_response :success, response.body

    call(:post, "/workspaces/#{@root.id}/actions/library_libraries_for", @viewer_token)
    assert_response :success, response.body

    call(:post, "/showcases/#{holder.id}/actions/library_resolve_placements", @viewer_token)
    assert_response :success, response.body
  end

  test "auth_roles view admin forbids a viewer from library reads" do
    RecordingStudioLibrary.library_for(@root, actor: @owner)
    previous = RecordingStudioLibrary.configuration.auth_roles.dup
    RecordingStudioLibrary.configuration.auth_roles = previous.merge(view: :admin)

    call(:post, "/workspaces/#{@root.id}/actions/library_libraries_for", @viewer_token)
    assert_response :forbidden, response.body

    call(:post, "/workspaces/#{@root.id}/actions/library_find_library", @viewer_token)
    assert_response :forbidden, response.body
  ensure
    RecordingStudioLibrary.configuration.auth_roles = previous if previous
  end

  test "auth_roles upload admin forbids place and reorder with 403" do
    library = RecordingStudioLibrary.library_for(@root, actor: @owner)
    holder = showcase_recording("Tight gallery")
    item = sample_item(library, "Tight still")
    placement = RecordingStudioLibrary.place!(holder, item, actor: @owner)
    previous = RecordingStudioLibrary.configuration.auth_roles.dup
    RecordingStudioLibrary.configuration.auth_roles = previous.merge(upload: :admin)

    call(:post, "/showcases/#{holder.id}/actions/library_place", @editor_token, item_recording_id: item.id)
    assert_response :forbidden, response.body
    refute_equal 422, response.status

    call(
      :post,
      "/showcases/#{holder.id}/actions/library_reorder_placements",
      @editor_token,
      ordered_recording_ids: [placement.id]
    )
    assert_response :forbidden, response.body
    refute_equal 422, response.status
  ensure
    RecordingStudioLibrary.configuration.auth_roles = previous if previous
  end

  test "a recording in another workspace is not found" do
    other_holder = nil
    Current.actor = @stranger
    other_holder = RecordingStudio.record!(
      action: "created",
      recordable: Showcase.create!(title: "Elsewhere gallery"),
      root_recording: @other_root,
      parent_recording: @other_root,
      actor: @stranger
    ).recording
    Current.actor = @owner

    call(:post, "/workspaces/#{@other_root.id}/actions/library_find_library", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/workspaces/#{@other_root.id}/actions/library_open_library", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/showcases/#{other_holder.id}/actions/library_resolve_placements", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/showcases/#{other_holder.id}/actions/library_place", @editor_token, item_recording_id: @root.id)
    assert_response :not_found, response.body
  end

  test "library capability actions match Accessible roles" do
    open_library = RecordingStudioApi.capability_action(:library_open_library)
    find_library = RecordingStudioApi.capability_action(:library_find_library)
    libraries_for = RecordingStudioApi.capability_action(:library_libraries_for)
    place = RecordingStudioApi.capability_action(:library_place)
    place_new = RecordingStudioApi.capability_action(:library_place_new)
    reorder = RecordingStudioApi.capability_action(:library_reorder_placements)
    remove = RecordingStudioApi.capability_action(:library_remove_placement)
    resolve = RecordingStudioApi.capability_action(:library_resolve_placements)

    assert_equal :edit, open_library.required_role
    assert_equal :view, find_library.required_role
    assert_equal :view, libraries_for.required_role
    assert_equal :edit, place.required_role
    assert_equal :edit, place_new.required_role
    assert_equal :edit, reorder.required_role
    assert_equal :admin, remove.required_role
    assert_equal :view, resolve.required_role
    assert_equal :library, open_library.capability
    assert_equal :placeable, place.capability
    assert_equal :placeable, reorder.capability

    workspace = RecordingStudioApi.recordable_registration_for("Workspace")
    showcase = RecordingStudioApi.recordable_registration_for("Showcase")
    assert_equal %w[library_find_library library_libraries_for library_open_library], workspace.capability_actions.sort
    assert_equal %w[library_place library_place_new library_remove_placement library_reorder_placements library_resolve_placements],
                 showcase.capability_actions.sort
    refute RecordingStudioApi.recordable_registration_for("RecordingStudioLibrary::Library")
    refute RecordingStudioApi.recordable_registration_for("RecordingStudioLibrary::Placement")
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.root_recording_for(recordable)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor:)
    raise result.error if result.failure?

    [root, result.value]
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording:, actor:, role:, manager_actor: @owner)
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    RecordingStudioAccessible::AccessCreationContext.allow do
      provision = RecordingStudioApi::Services::ProvisionApiClient.call(
        access_point_recording: access_recording.parent_recording || access_recording.root_recording,
        manager_actor: @owner,
        role: access_recording.recordable.role,
        name: "Client #{SecureRandom.hex(3)}"
      )
      raise provision.error unless provision.success?

      issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
        grant_type: "client_credentials",
        client_id: provision.value.fetch(:credential).oauth_client_id,
        client_secret: provision.value.fetch(:token)
      )
      raise issued.error unless issued.success?

      [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
    end
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params:, headers: {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }, as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def showcase_recording(title)
    RecordingStudio.record!(
      action: "created",
      recordable: Showcase.create!(title: title),
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
  end

  def sample_item(library, title)
    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioLibrary::SampleItem.new(title: title, accent: "ink"),
      root_recording: @root,
      parent_recording: library,
      actor: @owner
    ).recording
  end
end
