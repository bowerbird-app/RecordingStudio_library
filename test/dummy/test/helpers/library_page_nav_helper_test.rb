# frozen_string_literal: true

require "test_helper"

class LibraryPageNavHelperTest < ActionView::TestCase
  include RecordingStudioLibrary::ApplicationHelper

  test "fills host page nav when recording_studio_page_nav exists" do
    filled = nil
    define_singleton_method(:recording_studio_page_nav) { |**kwargs| filled = kwargs }

    html = library_screen_page_nav(back_url: "/home", title: "Library")

    assert_nil html
    assert_equal "/home", filled[:page_nav_back_url]
    assert_equal "Library", filled[:title]
    refute_includes html.to_s, "flat-pack-page-nav"
    refute_includes html.to_s, "Return to source page"
  end

  test "renders engine page nav when recording_studio_page_nav is missing" do
    define_singleton_method(:respond_to?) do |name, include_all = false|
      return false if name.to_sym == :recording_studio_page_nav

      super(name, include_all)
    end

    html = library_screen_page_nav(back_url: "/home").to_s

    assert_includes html, "flat-pack-page-nav"
    assert_includes html, "Return to source page"
  end
end
