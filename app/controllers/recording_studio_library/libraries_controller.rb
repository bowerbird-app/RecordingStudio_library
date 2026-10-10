# frozen_string_literal: true

module RecordingStudioLibrary
  class LibrariesController < ApplicationController
    def show
      recording = find_recording(params[:id] || params[:recording_id])
      RecordingStudioLibrary::Authorization.authorize_library!(
        action: :view,
        actor: current_library_actor,
        recording: recording
      )
      @library = library_from(recording)
      @view_mode = params[:view].to_s == "list" ? :list : :grid
      @query = params[:q].to_s
      @type = params[:type].to_s.presence
      @items = Services::LibraryItems.call(
        library_recording: @library,
        query: @query,
        type: @type,
        actor: current_library_actor
      ).value || []
      @type_options = type_options_for(@library)
      @can_add = RecordingStudioLibrary::Authorization.library_allowed?(
        action: :upload,
        actor: current_library_actor,
        recording: @library
      )
    end

    private

    def library_from(recording)
      return recording if Placements.library_recording?(recording)

      RecordingStudioLibrary.library_for(
        recording,
        key: params[:key].presence || :default,
        actor: current_library_actor
      )
    end

    def type_options_for(library)
      items = Services::LibraryItems.call(
        library_recording: library,
        actor: current_library_actor
      ).value || []
      items.map { |recording, adapter| [adapter.type_label, recording.recordable_type] }.uniq
    end
  end
end
