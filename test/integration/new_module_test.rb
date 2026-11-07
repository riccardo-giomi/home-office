require "test_helper"

# A new module (documents, say) gets trash, links, purge and MCP tools by including the concern and listing its kind,
# its tools and its overview in its manifest: nothing in Core or the Planner changes. Proved here with a throwaway table.
class NewModuleTest < ActionDispatch::IntegrationTest
  include McpHelpers

  let(:admin) { users(:admin) }
  let(:connection) { ActiveRecord::Base.connection }

  # The tool that the module offers to agents: the titles of the notes of the user of the token
  let(:notes_tool) do
    Class.new(Core::Mcp::Tool) do
      tool_name "list_test_notes"
      description "The titles of the notes of the user."
      access :read
      input_schema(properties: {}, required: [])

      def self.call(server_context:)
        respond(titles: TestNote.where(user_id: server_context[:user].id).kept.map(&:title))
      end
    end
  end

  before do
    # Defined here and removed after: including the concern registers the class with the integrity test
    Object.const_set(:TestNote, Class.new(ApplicationRecord) {
      include Core::EntityRecord

      belongs_to :user
    })
    connection.create_table(:test_notes) do |t|
      t.integer :user_id, null: false
      t.string :record_type, null: false, default: "TestNote"
      t.string :title, null: false
      t.foreign_key :core_entities, column: [:id, :user_id, :record_type], primary_key: [:id, :user_id, :record_type], on_delete: :cascade
    end
    I18n.backend.store_translations(:en, test_notes: {one: "Note", other: "Notes"})
    @modules = Core::Modules.all
    Core::Modules.register(Core::ModuleManifest.new(
      name: "test_notes",
      linkable_kinds: [
        Core::LinkableKind.new(key: "test_note", label_key: "test_notes", scope: ->(user) { TestNote.where(user_id: user.id).kept }, new_route: nil)
      ],
      mcp_tools: [notes_tool],
      mcp_overview: ->(user, _today) { {notes: TestNote.where(user_id: user.id).kept.count} }
    ))
    admin.update!(locale: "en")
  end

  after do
    Core::Modules.reset!
    @modules.each { |manifest| Core::Modules.register(manifest) }
    Core::EntityRecord.record_classes.delete(TestNote)
    connection.drop_table(:test_notes, if_exists: true)
    Object.send(:remove_const, :TestNote)
  end

  let(:note) { TestNote.create!(user: admin, title: "Meeting minutes") }
  let(:event) { planner_items(:holiday) }

  it "has an entity, and links to a record of another module like any other" do
    link = Core::Link.connect(admin, note.id, event.id)
    _(link).must_be :persisted?
    ends = Core::LinkIndex.new(event.id).ends_of(event.id)
    _(ends.map { |link_end| [link_end.kind_key, link_end.label] }).must_equal [["test_note", "Meeting minutes"]]
  end

  it "is offered by the picker, under its own kind, and linked from there" do
    note
    sign_in_as admin
    get new_link_path(entity_id: event.id, kind: "test_note")
    assert_select "a[aria-current=true]", text: "Notes"
    assert_select "li", text: /Meeting minutes/
    post links_path, params: {entity_id: event.id, other_id: note.id}
    _(Core::Link.existing(admin.id, note.id, event.id)).wont_be_nil
  end

  it "goes to the trash, is shown there on the other record, and comes back" do
    sign_in_as admin
    Core::Link.connect(admin, note.id, event.id)
    note.entity.update_columns(deleted_at: Time.current)
    get planner_event_path(event)
    assert_select "#links-section li", text: /Meeting minutes.*in the trash/m
    assert_select "#links-section h2", text: "Links (0)"
    note.entity.update_columns(deleted_at: nil)
    _(Core::LinkIndex.new(event.id).kept_count(event.id)).must_equal 1
  end

  it "is purged with its links, and the other end is left alone" do
    Core::Link.connect(admin, note.id, event.id)
    note.entity.update_columns(deleted_at: 31.days.ago)
    Core::PurgeTrashJob.perform_now
    _(TestNote.exists?(note.id)).must_equal false
    _(Core::Link.involving(event.id)).must_be_empty
    _(Planner::Item.exists?(event.id)).must_equal true
  end

  it "keeps another user's note out of the picker" do
    sign_in_as admin
    foreign = TestNote.create!(user: users(:other_admin), title: "Not yours")
    get new_link_path(entity_id: event.id, kind: "test_note")
    assert_select "li", text: /Not yours/, count: 0
    post links_path, params: {entity_id: event.id, other_id: foreign.id}
    assert_response :not_found
  end

  it "offers its tool to an agent, which sees the notes of the user of the token only" do
    note
    TestNote.create!(user: users(:other_admin), title: "Not yours")
    _(tool_names("admin_write")).must_include "list_test_notes"
    call_tool("admin_write", "list_test_notes")
    _(tool_data).must_equal({"titles" => ["Meeting minutes"]})
  end

  it "reports itself in the overview, under its own name" do
    note
    call_tool("admin_write", "overview")
    _(tool_data.dig("test_notes", "notes")).must_equal 1
  end
end
