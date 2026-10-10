# frozen_string_literal: true

module RecordingStudioLibrary
  class SampleItemsController < ApplicationController
    def new
      @library = find_library
      authorize_library!(:upload, @library)
      @sample_item = SampleItem.new
      @adapter = adapter_for_recordable(@sample_item)
    end

    def create
      @library = find_library
      authorize_library!(:upload, @library)
      create_item(@library)
      redirect_to library_path(@library, library_navigation_params),
                  notice: t("recording_studio.library.flashes.item_added")
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      @sample_item = SampleItem.new(sample_item_params)
      @adapter = adapter_for_recordable(@sample_item)
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def show
      @item_recording = find_item
      @library = @item_recording.parent_recording
      authorize_library!(:view, @library)
      @adapter = RecordingStudioLibrary.adapter_for(@item_recording)
      @usages = RecordingStudioLibrary.usages(@item_recording)
      @can_remove = RecordingStudioLibrary::Authorization.library_allowed?(
        action: :remove,
        actor: current_library_actor,
        recording: @library
      )
    end

    def edit
      @item_recording = find_item
      @library = @item_recording.parent_recording
      authorize_library!(:revise, @library)
      @sample_item = @item_recording.recordable
      @adapter = RecordingStudioLibrary.adapter_for(@item_recording)
    end

    def update
      @item_recording = find_item
      @library = @item_recording.parent_recording
      authorize_library!(:revise, @library)
      @sample_item = @item_recording.recordable
      if @sample_item.update(sample_item_params)
        redirect_to sample_item_path(@item_recording, library_navigation_params),
                    notice: t("recording_studio.library.flashes.item_updated")
      else
        @adapter = RecordingStudioLibrary.adapter_for(@item_recording)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @item_recording = find_item
      @library = @item_recording.parent_recording
      authorize_library!(:remove, @library)
      usages = RecordingStudioLibrary.usages(@item_recording)
      if @item_recording.respond_to?(:recording_studio_trashable_trash!)
        @item_recording.recording_studio_trashable_trash!(actor: current_library_actor)
      else
        @item_recording.destroy!
      end
      redirect_to library_path(@library, library_navigation_params),
                  notice: usages.any? ? t("recording_studio.library.flashes.trashed_in_use") : t("recording_studio.library.flashes.trashed")
    end

    private

    def find_library
      recording = find_recording(params[:recording_id] || params[:library_id])
      return recording if Placements.library_recording?(recording)

      RecordingStudioLibrary.library_for(recording, key: params[:key].presence || :default, actor: current_library_actor)
    end

    def find_item
      recording = RecordingStudio::Recording.find(params[:id])
      raise ActiveRecord::RecordNotFound unless recording.recordable_type == SampleItem.name

      recording
    end

    def authorize_library!(action, recording)
      RecordingStudioLibrary::Authorization.authorize_library!(
        action: action,
        actor: current_library_actor,
        recording: recording
      )
    end

    def create_item(library)
      recordable = SampleItem.new(sample_item_params)
      RecordingStudio.record!(
        action: "created",
        recordable: recordable,
        root_recording: library.root_recording || library,
        parent_recording: library,
        actor: current_library_actor
      ).recording
    end

    def adapter_for_recordable(recordable)
      Adapters::Dummy.new(Struct.new(:recordable, :recordable_type).new(recordable, SampleItem.name))
    end

    def sample_item_params
      params.require(:sample_item).permit(:title, :summary, :accent)
    rescue ActionController::ParameterMissing
      params.fetch(:recording_studio_library_sample_item, {}).permit(:title, :summary, :accent)
    end
  end
end
