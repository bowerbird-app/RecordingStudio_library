# frozen_string_literal: true

require "test_helper"

class AdaptersTest < Minitest::Test
  Sample = Struct.new(:title, :summary, :accent, keyword_init: true)
  Recording = Struct.new(:recordable, :recordable_type, keyword_init: true)

  def setup
    @original = RecordingStudioLibrary::Adapters.registry.dup
  end

  def teardown
    RecordingStudioLibrary::Adapters.registry.clear
    @original.each { |type, adapter| RecordingStudioLibrary::Adapters.register(type, adapter) }
  end

  def test_dummy_adapter_is_registered_for_sample_items
    assert_equal RecordingStudioLibrary::Adapters::Dummy,
                 RecordingStudioLibrary::Adapters.for("RecordingStudioLibrary::SampleItem")
  end

  def test_unknown_types_fall_back_to_base
    assert_equal RecordingStudioLibrary::Adapters::Base, RecordingStudioLibrary::Adapters.for("Unknown::Thing")
  end

  def test_register_overrides_a_type
    custom = Class.new(RecordingStudioLibrary::Adapters::Base)
    RecordingStudioLibrary::Adapters.register("Page", custom)

    assert_equal custom, RecordingStudioLibrary::Adapters.for("Page")
  end

  def test_dummy_exposes_title_search_and_accent
    recording = Recording.new(
      recordable: Sample.new(title: "Coral poster", summary: "Warm still", accent: "coral"),
      recordable_type: "RecordingStudioLibrary::SampleItem"
    )
    adapter = RecordingStudioLibrary.adapter_for(recording)

    assert_equal "Coral poster", adapter.title
    assert_includes adapter.search_text.downcase, "warm still"
    assert adapter.matches?("coral")
    refute adapter.matches?("missing")
    assert_equal "#e07a5f", adapter.accent_hex
    assert_equal :sparkles, adapter.icon
    assert_equal "Sample", adapter.type_label
  end

  def test_dummy_type_label_falls_back_for_other_recordables
    recording = Recording.new(
      recordable: Sample.new(title: "Stage notes"),
      recordable_type: "Page"
    )

    assert_equal "Page", RecordingStudioLibrary::Adapters::Dummy.new(recording).type_label
  end
end
