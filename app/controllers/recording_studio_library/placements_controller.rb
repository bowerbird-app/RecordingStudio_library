# frozen_string_literal: true

module RecordingStudioLibrary
  class PlacementsController < ApplicationController
    def index
      @recording = find_recording
      authorize!(:view, @recording)
      @resolved = RecordingStudioLibrary.resolve(@recording, actor: current_library_actor)
      @picker_libraries = RecordingStudioLibrary::Placements.picker_libraries_for(@recording)
      @library = @picker_libraries.first
      @can_add = RecordingStudioLibrary::Authorization.placement_allowed?(
        action: :upload,
        actor: current_library_actor,
        recording: @recording
      )
      @can_remove = RecordingStudioLibrary::Authorization.placement_allowed?(
        action: :remove,
        actor: current_library_actor,
        recording: @recording
      )
      @can_reorder = @can_add && @recording.respond_to?(:recording_studio_orderable_reorder!)
      @picker_modal_id = "library-picker-#{@recording.id}"
    end

    def create
      recording = find_recording
      authorize!(:upload, recording)
      ids = Array(params[:item_recording_ids]).presence || Array(params.dig(:placement, :item_recording_id))
      errors = []
      ids.each do |id|
        item = RecordingStudio::Recording.find(id)
        result = Services::Place.call(
          parent_recording: recording,
          item_recording: item,
          actor: current_library_actor
        )
        errors << result.error if result.failure?
      end

      redirect_to recording_placements_path(recording, library_navigation_params),
                  errors.empty? ? { notice: t("recording_studio.library.flashes.added") } : { alert: errors.first }
    end

    def reorder
      recording = find_recording
      authorize!(:revise, recording)
      result = Services::ReorderPlacements.call(
        parent_recording: recording,
        ordered_recording_ids: params[:ordered_recording_ids],
        moving_recording_id: params[:moving_recording_id],
        target_position: params[:target_position],
        actor: current_library_actor
      )

      if request.format.json? || request.xhr?
        return render json: { ok: result.success? }, status: result.success? ? :ok : :unprocessable_entity
      end

      redirect_to recording_placements_path(recording, library_navigation_params),
                  result.success? ? { notice: t("recording_studio.library.flashes.reordered") } : { alert: result.error }
    end

    def destroy
      placement = find_placement
      parent = placement.parent_recording
      authorize!(:remove, parent)
      result = Services::RemovePlacement.call(
        parent_recording: parent,
        placement_recording: placement,
        actor: current_library_actor
      )

      redirect_to recording_placements_path(parent, library_navigation_params),
                  result.success? ? { notice: t("recording_studio.library.flashes.removed") } : { alert: result.error }
    end

    private

    def authorize!(action, recording)
      RecordingStudioLibrary::Authorization.authorize_placement!(
        action: action,
        actor: current_library_actor,
        recording: recording
      )
    end

    def find_placement
      recording = RecordingStudio::Recording.find(params[:id])
      raise ActiveRecord::RecordNotFound unless Placements.placement_recording?(recording)

      recording
    end
  end
end
