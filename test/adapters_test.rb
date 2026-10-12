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
    refute RecordingStudioLibrary::Adapters.registered?("Unknown::Thing")
  end

  def test_registered_predicate_is_true_for_sample_items
    assert RecordingStudioLibrary::Adapters.registered?("RecordingStudioLibrary::SampleItem")
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

  def test_dummy_thumbnail_fills_card_media_without_its_own_radius
    adapter = dummy_adapter
    html = adapter.thumbnail(tag_view)

    refute_includes html, "rounded-lg"
    assert_includes html, "h-full w-full"
    assert_includes html, "background-color: #e07a5f"
  end

  def test_dummy_preview_keeps_a_rounded_swatch
    adapter = dummy_adapter
    html = adapter.preview(tag_view)

    assert_includes html, "rounded-lg"
    assert_includes html, "h-12 w-12"
  end

  def test_base_thumbnail_does_not_reuse_the_rounded_preview_chip
    adapter = RecordingStudioLibrary::Adapters::Base.new(
      Recording.new(recordable: Sample.new(title: "Notes"), recordable_type: "Page")
    )
    html = adapter.thumbnail(tag_view)

    refute_includes html, "rounded-lg"
    assert_includes html, "h-full w-full"
  end

  def test_dummy_permits_sample_item_fields_and_ignores_unknown_keys
    adapter = dummy_adapter

    permitted = adapter.permit_item_attrs(
      title: "Lobby still",
      summary: "From PATCH",
      extra: "ignored"
    )

    assert_equal({ title: "Lobby still", summary: "From PATCH" }, permitted)
  end

  def test_base_item_paths_are_blank
    adapter = RecordingStudioLibrary::Adapters::Base.new(
      Recording.new(recordable: Sample.new(title: "Notes"), recordable_type: "Page")
    )

    assert_nil adapter.item_path(nil)
    assert_nil adapter.new_item_path(nil, nil)
    assert_equal %i[title], adapter.permitted_item_keys
  end

  def test_dummy_type_label_falls_back_for_other_recordables
    recording = Recording.new(
      recordable: Sample.new(title: "Stage notes"),
      recordable_type: "Page"
    )

    assert_equal "Page", RecordingStudioLibrary::Adapters::Dummy.new(recording).type_label
  end

  private

  def dummy_adapter
    RecordingStudioLibrary.adapter_for(
      Recording.new(
        recordable: Sample.new(title: "Coral poster", summary: "Warm still", accent: "coral"),
        recordable_type: "RecordingStudioLibrary::SampleItem"
      )
    )
  end

  def tag_view
    TagView.new
  end

  class TagView
    def tag
      TagBuilder.new
    end

    class TagBuilder
      def div(**attributes)
        inner = block_given? ? yield : ""
        %(<div#{html_attributes(attributes)}>#{inner}</div>)
      end

      def span(*args, **attributes)
        content = args.first.to_s
        %(<span#{html_attributes(attributes)}>#{content}</span>)
      end

      private

      def html_attributes(attributes)
        attributes.filter_map do |key, value|
          name = key.to_s.tr("_", "-")
          serialized = value.is_a?(Hash) ? value.map { |nested, nested_value| "#{nested}: #{nested_value}" }.join("; ") : value
          next if serialized.blank?

          %( #{name}="#{serialized}")
        end.join
      end
    end
  end
end
