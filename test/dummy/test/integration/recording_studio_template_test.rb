# frozen_string_literal: true

require "test_helper"

class RecordingStudioTemplateTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "Workspace" ], RecordingStudio.root_recordable_types
    assert_includes RecordingStudio.allowed_parent_types_for("Page"), "Workspace"
    assert_includes RecordingStudio.allowed_parent_types_for("Page"), "RecordingStudioLibrary::Library"
  end

  test "dummy app schema keeps accessible grants and excludes removed core tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "workspace opts into library without enabling it globally" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))

    assert_includes workspace_source, "include RecordingStudio::Capabilities::Library.to("
    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    assert RecordingStudio.capability_enabled?(:library, for: Workspace)
    refute RecordingStudio.capability_enabled?(:library, for: Folder)
    refute RecordingStudio.capability_enabled?(:placeable, for: Workspace)
    assert RecordingStudio.capability_enabled?(:placeable, for: Showcase)
  end
end
