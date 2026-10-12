# frozen_string_literal: true

require "uri"

module RecordingStudioLibrary
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    protect_from_forgery with: :exception
    layout :recording_studio_library_layout

    rescue_from RecordingStudioLibrary::Authorization::NotAuthorizedError, with: :handle_not_authorized
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

    helper_method :current_library_actor
    helper_method :library_navigation_params
    helper_method :library_page_nav_anchor_url
    helper_method :modal_request?

    private

    def current_library_actor
      if defined?(Current) && Current.respond_to?(:actor)
        actor = Current.actor
        return actor unless actor.nil?
      end
      return current_user if respond_to?(:current_user, true)

      nil
    end

    def find_recording(id = params[:recording_id] || params[:id])
      RecordingStudio::Recording.find(id)
    end

    def find_library_recording(recording, key: params[:key].presence || :default)
      return recording if Placements.library_recording?(recording)

      library = RecordingStudioLibrary.find_library(recording, key: key)
      raise ActiveRecord::RecordNotFound if library.blank?

      library
    end

    def handle_not_authorized(exception)
      respond_to do |format|
        format.html { redirect_back_or_to(main_app.root_path, alert: exception.message) }
        format.json { render json: { error: exception.message }, status: :forbidden }
      end
    end

    def handle_record_not_found
      respond_to do |format|
        format.html { redirect_back_or_to(main_app.root_path, alert: t("recording_studio.library.errors.not_found")) }
        format.json { render json: { error: t("recording_studio.library.errors.not_found") }, status: :not_found }
      end
    end

    def library_navigation_params
      return_to = params[:return_to].presence || (params[:redirect_mode] == "referer" ? request.referer : nil)
      {
        redirect_mode: params[:redirect_mode].presence,
        return_to: validated_local_redirect_target(return_to),
        modal: params[:modal].presence,
        modal_id: params[:modal_id].presence
      }.compact
    end

    def library_page_nav_anchor_url(fallback:)
      library_navigation_params[:return_to].presence || fallback
    end

    def modal_request?
      params[:modal].to_s == "1" || params[:modal_id].present?
    end

    def modal_id
      params[:modal_id].presence || "library-picker"
    end

    def recording_studio_library_layout
      return false if modal_request?

      configured = RecordingStudioLibrary.configuration.layout
      return "recording_studio/default_layout" if configured.blank? || configured.to_sym == :default

      configured.to_s
    end

    def validated_local_redirect_target(target)
      return if target.blank?

      uri = URI.parse(target.to_s)
      return unless valid_local_redirect_uri?(uri)

      [uri.path, uri.query.presence && "?#{uri.query}", uri.fragment.presence && "##{uri.fragment}"].compact.join
    rescue URI::InvalidURIError
      nil
    end

    def valid_local_redirect_uri?(uri)
      return false unless uri.path&.start_with?("/")
      return false if uri.host.present? && !same_origin_redirect_uri?(uri)
      return false if uri.scheme.present? && !same_origin_redirect_uri?(uri)

      true
    end

    def same_origin_redirect_uri?(uri)
      base_uri = URI.parse(request.base_url)
      uri.scheme == base_uri.scheme && uri.host == base_uri.host && uri.port == base_uri.port
    rescue URI::InvalidURIError
      false
    end
  end
end
