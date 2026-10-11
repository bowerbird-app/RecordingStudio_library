module ApplicationHelper
  include RecordingStudioLibrary::ApplicationHelper

  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )
    dummy_page_nav_right_chrome
  end

  def library_screen_page_nav(**options)
    super
    dummy_page_nav_right_chrome
    nil
  end

  def dummy_page_nav_right_chrome
    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          url: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
