# frozen_string_literal: true

module RecordingStudioLibrary
  class PickersController < ApplicationController
    def index
      @holder = find_recording
      RecordingStudioLibrary::Authorization.authorize_placement!(
        action: :view,
        actor: current_library_actor,
        recording: @holder
      )
      @picker_libraries = RecordingStudioLibrary::Placements.picker_libraries_for(@holder)
      @library = selected_library
      @query = params[:q].to_s
      @type = params[:type].to_s.presence
      @items = if @library.present?
                 Services::LibraryItems.call(
                   library_recording: @library,
                   query: @query,
                   type: @type,
                   actor: current_library_actor
                 ).value || []
               else
                 []
               end
      @type_options = type_options_for(@library)
      @placed_ids = RecordingStudioLibrary.resolve(@holder, actor: current_library_actor).map { |item| item.item_recording.id.to_s }
      @can_add = RecordingStudioLibrary::Authorization.placement_allowed?(
        action: :upload,
        actor: current_library_actor,
        recording: @holder
      )
      @modal_id = modal_id

      render layout: false if modal_request?
    end

    private

    def selected_library
      return if @picker_libraries.blank?

      requested = params[:library_id].presence
      chosen = @picker_libraries.find { |library| library.id.to_s == requested.to_s } if requested
      chosen || @picker_libraries.first
    end

    def type_options_for(library)
      return [] if library.blank?

      items = Services::LibraryItems.call(
        library_recording: library,
        actor: current_library_actor
      ).value || []
      items.map { |recording, adapter| [adapter.type_label, recording.recordable_type] }.uniq
    end
  end
end
