# frozen_string_literal: true

require "test_helper"

class PlacementsTest < Minitest::Test
  PlacementRecordable = Struct.new(:id, :item_recording_id, keyword_init: true)

  Recording = Struct.new(:id, :recordable_type, :parent_recording_id, :root_recording_id, :root_recording, :recordable,
                         :trashed_at, :parent_recording, :child_recordings, :placed, keyword_init: true) do
    attr_accessor :trashed_with, :destroyed, :reordered_with, :appended, :moved_with

    def record(_type, parent_recording:, **)
      placement = PlacementsTest::PlacementRecordable.new
      yield placement if block_given?
      child = Recording.new(
        id: "place-#{Array(placed).size + 1}",
        recordable_type: "RecordingStudioLibrary::Placement",
        parent_recording_id: parent_recording.id,
        root_recording_id: root_recording_id,
        recordable: placement
      )
      self.placed = Array(placed) + [child]
      child
    end

    def recording_studio_orderable_append!(child, actor:)
      self.appended = [child, actor]
      child
    end

    def recording_studio_orderable_reorder!(ordered_recording_ids:, actor:)
      self.reordered_with = [ordered_recording_ids, actor]
    end

    def recording_studio_orderable_move!(moving, to_index:, actor:)
      self.moved_with = [moving, to_index, actor]
    end

    def recording_studio_orderable_children
      Array(placed)
    end

    def recording_studio_trashable_trash!(actor:, impersonator: nil)
      self.trashed_with = [actor, impersonator]
      self.trashed_at = Time.now
    end

    def destroy!
      self.destroyed = true
    end
  end

  Item = Struct.new(:id, :title, keyword_init: true)
  ParentRecordable = Struct.new(:title, :name, keyword_init: true)

  def setup
    stub_placement_class!
    stub_authorization!
  end

  def teardown
    restore_authorization!
    restore_placement_class!
  end

  def test_place_records_a_pointer_and_appends_order
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(id: "lib-1", recordable_type: "RecordingStudioLibrary::Library", parent_recording_id: "root-1", root_recording_id: "root-1")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", root_recording_id: "root-1", root_recording: root)
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording_id: "lib-1",
      parent_recording: library,
      root_recording_id: "root-1",
      recordable: Item.new(id: "snap-1", title: "Hero")
    )

    result = RecordingStudioLibrary::Services::Place.call(
      parent_recording: parent,
      item_recording: item,
      actor: :ada
    )

    assert result.success?
    assert_equal "item-1", result.value.recordable.item_recording_id
    assert_equal [result.value, :ada], parent.appended
  end

  def test_place_refuses_an_item_outside_a_library
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    page = Recording.new(id: "page-1", recordable_type: "Page", parent_recording_id: "root-1", root_recording_id: "root-1")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", root_recording_id: "root-1", root_recording: root)
    item = Recording.new(
      id: "item-1",
      recordable_type: "Page",
      parent_recording_id: "page-1",
      parent_recording: page,
      root_recording_id: "root-1",
      recordable: Item.new(id: "note-1", title: "Stage notes")
    )

    result = RecordingStudioLibrary::Services::Place.call(
      parent_recording: parent,
      item_recording: item,
      actor: :ada
    )

    assert result.failure?
    assert_match(/not in a live library/, result.error)
    assert_nil parent.placed
  end

  def test_place_refuses_an_item_from_a_trashed_library
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(
      id: "lib-1",
      recordable_type: "RecordingStudioLibrary::Library",
      parent_recording_id: "root-1",
      root_recording_id: "root-1",
      trashed_at: Time.now
    )
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", root_recording_id: "root-1", root_recording: root)
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording_id: "lib-1",
      parent_recording: library,
      root_recording_id: "root-1",
      recordable: Item.new(id: "snap-1", title: "Hero")
    )

    result = RecordingStudioLibrary::Services::Place.call(
      parent_recording: parent,
      item_recording: item,
      actor: :ada
    )

    assert result.failure?
    assert_match(/not in a live library/, result.error)
  end

  def test_place_refuses_another_workspace
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    other = Recording.new(id: "root-2", recordable_type: "Workspace")
    other_library = Recording.new(id: "lib-2", recordable_type: "RecordingStudioLibrary::Library", parent_recording_id: "root-2", root_recording_id: "root-2")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", root_recording_id: "root-1", root_recording: root)
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording_id: "lib-2",
      parent_recording: other_library,
      root_recording_id: "root-2",
      root_recording: other,
      recordable: Item.new(id: "snap-1", title: "Hero")
    )

    result = RecordingStudioLibrary::Services::Place.call(
      parent_recording: parent,
      item_recording: item,
      actor: :ada
    )

    assert result.failure?
    assert_match(/another workspace/, result.error)
  end

  def test_resolve_skips_trashed_items_and_keeps_the_placement
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(id: "lib-1", recordable_type: "RecordingStudioLibrary::Library")
    live_item = Recording.new(
      id: "item-live",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording_id: "lib-1",
      parent_recording: library,
      root_recording_id: "root-1",
      recordable: Item.new(id: "snap-live", title: "Live")
    )
    trashed_item = Recording.new(
      id: "item-trash",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording_id: "lib-1",
      parent_recording: library,
      root_recording_id: "root-1",
      trashed_at: Time.now,
      recordable: Item.new(id: "snap-trash", title: "Trashed")
    )
    live_placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-live")
    )
    trash_placement = Recording.new(
      id: "place-2",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-trash")
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      root_recording_id: "root-1",
      root_recording: root,
      placed: [live_placement, trash_placement]
    )
    items = { "item-live" => live_item, "item-trash" => trashed_item }

    stub_recordings(items) do
      resolved = RecordingStudioLibrary::Placements.resolve(parent)

      assert_equal 1, resolved.size
      assert_equal "place-1", resolved.first.placement_recording.id
      assert_equal "Live", resolved.first.item.title
    end
  end

  def test_resolve_skips_cross_root_items
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    foreign = Recording.new(
      id: "item-2",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      root_recording_id: "root-2",
      recordable: Item.new(id: "snap-2", title: "Foreign")
    )
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-2")
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      root_recording_id: "root-1",
      root_recording: root,
      placed: [placement]
    )

    stub_recordings("item-2" => foreign) do
      resolved = RecordingStudioLibrary::Placements.resolve(parent)

      assert_empty resolved
    end
  end

  def test_remove_placement_trashes_the_pointer_and_leaves_the_item
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase")
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      parent_recording_id: "gallery-1",
      recordable: PlacementRecordable.new(item_recording_id: "item-1")
    )

    result = RecordingStudioLibrary::Services::RemovePlacement.call(
      parent_recording: parent,
      placement_recording: placement,
      actor: :ada,
      impersonator: :imp
    )

    assert result.success?
    assert_equal %i[ada imp], placement.trashed_with
    assert_nil placement.destroyed
  end

  def test_reorder_uses_orderable
    place_one = Recording.new(id: "place-1", recordable_type: "RecordingStudioLibrary::Placement")
    place_two = Recording.new(id: "place-2", recordable_type: "RecordingStudioLibrary::Placement")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", placed: [place_one, place_two])

    result = RecordingStudioLibrary::Services::ReorderPlacements.call(
      parent_recording: parent,
      ordered_recording_ids: %w[place-2 place-1],
      actor: :ada
    )

    assert result.success?
    assert_equal [%w[place-2 place-1], :ada], parent.reordered_with
  end

  def test_reorder_moves_with_one_based_target_position
    moving = Recording.new(id: "place-2", recordable_type: "RecordingStudioLibrary::Placement")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", placed: [moving])
    result = RecordingStudioLibrary::Services::ReorderPlacements.call(
      parent_recording: parent,
      moving_recording_id: "place-2",
      target_position: 1,
      actor: :ada
    )

    assert result.success?
    assert_equal [moving, 0, :ada], parent.moved_with
  end

  def test_reorder_refuses_another_holders_placement
    own = Recording.new(id: "place-1", recordable_type: "RecordingStudioLibrary::Placement")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", placed: [own])

    result = RecordingStudioLibrary::Services::ReorderPlacements.call(
      parent_recording: parent,
      moving_recording_id: "place-foreign",
      target_position: 1,
      actor: :ada
    )

    assert result.failure?
    assert_match(/not on this page/, result.error)
    assert_nil parent.moved_with
  end

  def test_reorder_refuses_foreign_ids_in_a_full_order
    own = Recording.new(id: "place-1", recordable_type: "RecordingStudioLibrary::Placement")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", placed: [own])

    result = RecordingStudioLibrary::Services::ReorderPlacements.call(
      parent_recording: parent,
      ordered_recording_ids: %w[place-1 place-foreign],
      actor: :ada
    )

    assert result.failure?
    assert_match(/not on this page/, result.error)
    assert_nil parent.reordered_with
  end

  def test_usage_names_the_places
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      recordable: Item.new(id: "snap-1")
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      recordable: ParentRecordable.new(title: "Homepage gallery")
    )
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      parent_recording: parent,
      recordable: PlacementRecordable.new(id: "row-1", item_recording_id: "item-1")
    )

    RecordingStudioLibrary::Placement.stub(:where, placement_ids_relation(%w[row-1])) do
      relation = [placement]
      relation.define_singleton_method(:includes) { |*| relation }
      relation.define_singleton_method(:order) { |*| relation }
      recording_class.stub(:where, relation) do
        usages = RecordingStudioLibrary::Placements.usage_for(item)

        assert_equal 1, usages.size
        assert_equal "Homepage gallery", usages.first.label
        assert_equal parent, usages.first.parent_recording
      end
    end
  end

  def test_purge_destroys_placements_for_the_item
    item = Recording.new(id: "item-1", recordable_type: "RecordingStudioLibrary::SampleItem")
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(id: "row-1")
    )
    recordings = [placement]
    recordings.define_singleton_method(:to_a) { recordings }

    RecordingStudioLibrary::Placement.stub(:where, placement_ids_relation(%w[row-1])) do
      recording_class.stub(:unscoped, recording_class) do
        recording_class.stub(:where, recordings) do
          result = RecordingStudioLibrary::Services::PurgePlacements.call(item_recording: item)

          assert result.success?
          assert placement.destroyed
        end
      end
    end
  end

  def test_place_refuses_items_the_actor_cannot_see
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(id: "lib-1", recordable_type: "RecordingStudioLibrary::Library", root_recording_id: "root-1")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", root_recording_id: "root-1", root_recording: root)
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording_id: "lib-1",
      parent_recording: library,
      root_recording_id: "root-1",
      recordable: Item.new(id: "snap-1", title: "Hidden")
    )
    RecordingStudioLibrary::Authorization.define_singleton_method(:visible?) { |**| false }

    result = RecordingStudioLibrary::Services::Place.call(
      parent_recording: parent,
      item_recording: item,
      actor: :ada
    )

    assert result.failure?
    assert_match(/cannot place that item/, result.error)
    assert_nil parent.placed
  end

  def test_resolve_asks_accessible_for_anonymous_actors
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(id: "lib-1", recordable_type: "RecordingStudioLibrary::Library")
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording: library,
      parent_recording_id: "lib-1",
      root_recording_id: "root-1",
      recordable: Item.new(id: "snap-1", title: "Hero")
    )
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-1")
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      root_recording_id: "root-1",
      root_recording: root,
      placed: [placement]
    )
    seen = []
    RecordingStudioLibrary::Authorization.define_singleton_method(:visible?) do |actor:, recording:, unfiltered: false|
      seen << [actor, recording.id, unfiltered]
      false
    end

    stub_recordings("item-1" => item) do
      resolved = RecordingStudioLibrary::Placements.resolve(parent, actor: nil)

      assert_empty resolved
      assert_equal [[nil, "item-1", false]], seen
    end
  end

  def test_place_new_refuses_unregistered_types_before_recording
    parent, library = place_new_fixtures
    result = RecordingStudioLibrary::Services::PlaceNew.call(
      parent_recording: parent,
      library: library,
      type: "Unknown::Thing",
      actor: :ada
    )

    assert result.failure?
    assert_match(/not set up/, result.error)
  end

  def test_place_new_refuses_library_type_allow_list_before_recording
    parent, library = place_new_fixtures
    RecordingStudioLibrary::Authorization.define_singleton_method(:capability_options_for) do |capability, _recording|
      capability == :library ? { types: ["Page"] } : {}
    end

    result = RecordingStudioLibrary::Services::PlaceNew.call(
      parent_recording: parent,
      library: library,
      type: "RecordingStudioLibrary::SampleItem",
      actor: :ada
    )

    assert result.failure?
    assert_match(/cannot be placed/, result.error)
  end

  def test_place_label_falls_back_to_title_then_type
    titled = Recording.new(recordable: ParentRecordable.new(title: "Homepage gallery"))
    named = Recording.new(recordable: ParentRecordable.new(name: "Untitled kiln"))
    typed = Recording.new(recordable_type: "Showcase")

    assert_equal "Homepage gallery", RecordingStudioLibrary::Placements.place_label(titled)
    assert_equal "Untitled kiln", RecordingStudioLibrary::Placements.place_label(named)
    assert_equal "Showcase", RecordingStudioLibrary::Placements.place_label(typed)
  end

  def test_purge_hook_removes_placements_for_items
    recording = Object.new
    recording.extend(RecordingStudioLibrary::Purge)
    recording.define_singleton_method(:recordable_type) { "RecordingStudioLibrary::SampleItem" }
    captured = nil
    RecordingStudioLibrary::Placements.stub(:purge_for, ->(value) { captured = value }) do
      recording.recording_studio_library_purge_placements
    end

    assert_same recording, captured
  end

  def test_resolve_skips_items_outside_a_live_library
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    page = Recording.new(id: "page-1", recordable_type: "Page")
    item = Recording.new(
      id: "item-1",
      recordable_type: "Page",
      parent_recording: page,
      parent_recording_id: "page-1",
      root_recording_id: "root-1",
      recordable: Item.new(id: "note-1", title: "Stage notes")
    )
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-1")
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      root_recording_id: "root-1",
      root_recording: root,
      placed: [placement]
    )

    stub_recordings("item-1" => item) do
      resolved = RecordingStudioLibrary::Placements.resolve(parent)

      assert_empty resolved
    end
  end

  def test_resolve_unfiltered_skips_accessible_for_a_single_call
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(id: "lib-1", recordable_type: "RecordingStudioLibrary::Library")
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording: library,
      parent_recording_id: "lib-1",
      root_recording_id: "root-1",
      recordable: Item.new(id: "snap-1", title: "Hero")
    )
    placement = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-1")
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      root_recording_id: "root-1",
      root_recording: root,
      placed: [placement]
    )
    seen = []
    RecordingStudioLibrary::Authorization.define_singleton_method(:visible?) do |actor:, recording:, unfiltered: false|
      seen << [actor, recording.id, unfiltered]
      unfiltered
    end

    stub_recordings("item-1" => item) do
      hidden = RecordingStudioLibrary::Placements.resolve(parent, actor: nil)
      visible = RecordingStudioLibrary::Placements.resolve(parent, actor: nil, unfiltered: true)

      assert_empty hidden
      assert_equal 1, visible.size
      assert_equal [nil, "item-1", false], seen.first
      assert_equal [nil, "item-1", true], seen.last
    end
  end

  def test_update_placements_saves_adapter_fields_then_reorders
    library = Recording.new(id: "lib-1", recordable_type: "RecordingStudioLibrary::Library")
    item = Recording.new(
      id: "item-1",
      recordable_type: "RecordingStudioLibrary::SampleItem",
      parent_recording: library,
      recordable: Item.new(id: "snap-1", title: "Hero")
    )
    place_one = Recording.new(
      id: "place-1",
      recordable_type: "RecordingStudioLibrary::Placement",
      recordable: PlacementRecordable.new(item_recording_id: "item-1")
    )
    place_two = Recording.new(id: "place-2", recordable_type: "RecordingStudioLibrary::Placement")
    parent = Recording.new(id: "gallery-1", recordable_type: "Showcase", placed: [place_one, place_two])
    item.recordable.define_singleton_method(:assign_attributes) { |attrs| @assigned = attrs }
    item.recordable.define_singleton_method(:save!) { @saved = true }
    item.recordable.define_singleton_method(:assigned) { @assigned }
    item.recordable.define_singleton_method(:saved) { @saved }

    resolved = [
      RecordingStudioLibrary::Placements::Resolved.new(
        placement_recording: place_one,
        item_recording: item,
        item: item.recordable,
        adapter: RecordingStudioLibrary.adapter_for(item)
      )
    ]
    RecordingStudioLibrary::Placements.stub(:resolve, resolved) do
      result = RecordingStudioLibrary::Services::UpdatePlacements.call(
        parent_recording: parent,
        items: { "place-1" => { title: "Lobby still", extra: "ignored" } },
        ordered_recording_ids: %w[place-2 place-1],
        actor: :ada
      )

      assert result.success?
      assert_equal({ title: "Lobby still" }, item.recordable.assigned)
      assert item.recordable.saved
      assert_equal [%w[place-2 place-1], :ada], parent.reordered_with
    end
  end

  def test_purge_hook_removes_placements_for_a_library
    recording = Object.new
    recording.extend(RecordingStudioLibrary::Purge)
    recording.define_singleton_method(:recordable_type) { "RecordingStudioLibrary::Library" }
    captured = nil
    RecordingStudioLibrary::Placements.stub(:purge_library, ->(value) { captured = value }) do
      recording.recording_studio_library_purge_placements
    end

    assert_same recording, captured
  end

  private

  def stub_placement_class!
    return if defined?(RecordingStudioLibrary::Placement)

    RecordingStudioLibrary.const_set(
      :Placement,
      Class.new do
        attr_accessor :item_recording_id

        def self.where(*)
          Struct.new(:pluck).new([])
        end
      end
    )
    @created_placement_stub = true
  end

  def restore_placement_class!
    return unless @created_placement_stub && RecordingStudioLibrary.const_defined?(:Placement)

    RecordingStudioLibrary.send(:remove_const, :Placement)
  end

  def stub_authorization!
    auth = RecordingStudioLibrary::Authorization
    @original_assert_placement = auth.method(:assert_placement_enabled!)
    @original_authorize_placement = auth.method(:authorize_placement!)
    @original_authorize_library = auth.method(:authorize_library!)
    @original_visible = auth.method(:visible?)
    @original_options = auth.method(:capability_options_for)
    auth.define_singleton_method(:assert_placement_enabled!) { |**| true }
    auth.define_singleton_method(:authorize_placement!) { |**| true }
    auth.define_singleton_method(:authorize_library!) { |**| true }
    auth.define_singleton_method(:visible?) { |**| true }
    auth.define_singleton_method(:capability_options_for) { |*| {} }
    recording_class
  end

  def restore_authorization!
    auth = RecordingStudioLibrary::Authorization
    auth.define_singleton_method(:assert_placement_enabled!, @original_assert_placement) if @original_assert_placement
    auth.define_singleton_method(:authorize_placement!, @original_authorize_placement) if @original_authorize_placement
    auth.define_singleton_method(:authorize_library!, @original_authorize_library) if @original_authorize_library
    auth.define_singleton_method(:visible?, @original_visible) if @original_visible
    auth.define_singleton_method(:capability_options_for, @original_options) if @original_options
  end

  def recording_class
    studio = defined?(RecordingStudio) ? RecordingStudio : Object.const_set(:RecordingStudio, Module.new)
    studio.const_set(:Recording, Class.new) unless studio.const_defined?(:Recording)
    klass = studio::Recording
    %i[where includes find_by unscoped find].each do |method_name|
      next if klass.respond_to?(method_name)

      klass.define_singleton_method(method_name) { |*| klass }
    end
    klass
  end

  def placement_ids_relation(ids)
    relation = Object.new
    relation.define_singleton_method(:pluck) { |*| ids }
    relation
  end

  def stub_recordings(items, &)
    recording_class.stub(:where, lambda { |*args|
      ids = where_ids(args)
      found = ids.filter_map { |id| items[id.to_s] }
      found.define_singleton_method(:includes) { |*| found }
      found
    }, &)
  end

  def where_ids(args)
    first = args.first
    if first.is_a?(Hash)
      Array(first[:id] || first["id"])
    else
      Array(first)
    end
  end

  def place_new_fixtures
    root = Recording.new(id: "root-1", recordable_type: "Workspace")
    library = Recording.new(
      id: "lib-1",
      recordable_type: "RecordingStudioLibrary::Library",
      parent_recording: root,
      parent_recording_id: "root-1",
      root_recording_id: "root-1",
      root_recording: root
    )
    parent = Recording.new(
      id: "gallery-1",
      recordable_type: "Showcase",
      root_recording_id: "root-1",
      root_recording: root
    )
    [parent, library]
  end
end
