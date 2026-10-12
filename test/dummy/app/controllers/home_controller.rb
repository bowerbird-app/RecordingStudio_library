class HomeController < ApplicationController
  def index
    @workspace = Workspace.find_by(name: "Studio Workspace")
    @workspace_recording = RecordingStudio.root_recording_for(@workspace) if @workspace
    @library = RecordingStudioLibrary.find_library(@workspace_recording) if @workspace_recording
    @showcase = Showcase.find_by(title: "Homepage gallery")
    @showcase_recording = RecordingStudio::Recording.find_by(recordable: @showcase)
    @resolved = RecordingStudioLibrary.resolve(@showcase_recording, actor: Current.actor) if @showcase_recording
  end
end
