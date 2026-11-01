require "test_helper"

describe Core::Modules do
  before do
    @saved = Core::Modules.all
    Core::Modules.reset!
  end

  after do
    Core::Modules.reset!
    @saved.each { |manifest| Core::Modules.register(manifest) }
  end

  def manifest(name, navigation: [], setup_steps: [])
    Core::ModuleManifest.new(name:, navigation:, setup_steps:)
  end

  it "registers a manifest once by name" do
    Core::Modules.register(manifest("a"))
    Core::Modules.register(manifest("a"))
    _(Core::Modules.all.map(&:name)).must_equal ["a"]
  end

  it "lists navigation in registration order and hides admin entries from members" do
    open_item = Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home)
    admin_item = Core::NavItem.new(label_key: "core.nav.users", route: :admin_users_path, icon: :users, admin: true)
    Core::Modules.register(manifest("a", navigation: [open_item]))
    Core::Modules.register(manifest("b", navigation: [admin_item]))
    _(Core::Modules.navigation(admin: false)).must_equal [open_item]
    _(Core::Modules.navigation(admin: true)).must_equal [open_item, admin_item]
  end

  it "puts admin entries after every module's own entries, however they were registered" do
    admin_item = Core::NavItem.new(label_key: "core.nav.users", route: :admin_users_path, icon: :users, admin: true)
    first = Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home)
    second = Core::NavItem.new(label_key: "core.nav.preferences", route: :edit_preferences_path, icon: :cog)
    Core::Modules.register(manifest("a", navigation: [first, admin_item]))
    Core::Modules.register(manifest("b", navigation: [second]))
    _(Core::Modules.navigation(admin: true)).must_equal [first, second, admin_item]
  end

  it "keeps footer entries out of the main list and lists them apart" do
    main = Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home)
    footer = Core::NavItem.new(label_key: "core.nav.preferences", route: :edit_preferences_path, icon: :cog, placement: :footer)
    Core::Modules.register(manifest("a", navigation: [footer, main]))
    _(Core::Modules.navigation(admin: false)).must_equal [main]
    _(Core::Modules.navigation(admin: false, placement: :footer)).must_equal [footer]
  end

  it "collects setup steps in registration order" do
    Core::Modules.register(manifest("a", setup_steps: [:one]))
    Core::Modules.register(manifest("b", setup_steps: [:two]))
    _(Core::Modules.setup_steps).must_equal [:one, :two]
  end

  describe "linkable kinds" do
    def kind(key) = Core::LinkableKind.new(key:, label_key: "planner.link_kinds.#{key}", scope: ->(user) { Planner::Event.owned_by(user).kept }, new_route: nil)

    it "lists them in registration order and finds one by key" do
      Core::Modules.register(Core::ModuleManifest.new(name: "a", linkable_kinds: [kind("x"), kind("y")]))
      Core::Modules.register(Core::ModuleManifest.new(name: "b", linkable_kinds: [kind("z")]))
      _(Core::Modules.linkable_kinds.map(&:key)).must_equal %w[x y z]
      _(Core::Modules.linkable_kind("y").key).must_equal "y"
    end

    it "answers nil for a key it does not know, whatever it looks like" do
      _(Core::Modules.linkable_kind("Kernel")).must_be_nil
      _(Core::Modules.linkable_kind(nil)).must_be_nil
    end

    it "refuses a key that another module has" do
      Core::Modules.register(Core::ModuleManifest.new(name: "a", linkable_kinds: [kind("x")]))
      _ { Core::Modules.register(Core::ModuleManifest.new(name: "b", linkable_kinds: [kind("x")])) }.must_raise ArgumentError
    end
  end
end

describe "the booted registry" do
  it "offers the Planner's three kinds to link, each with the user's own kept records only" do
    _(Core::Modules.linkable_kinds.map(&:key)).must_equal %w[event task todo]
    admin = users(:admin)
    scopes = Core::Modules.linkable_kinds.to_h { |kind| [kind.key, kind.scope.call(admin).to_a] }
    _(scopes["event"].map(&:class).uniq).must_equal [Planner::Event]
    _(scopes["task"].map(&:class).uniq).must_equal [Planner::Task]
    _(scopes["todo"].map(&:class).uniq).must_equal [Planner::Todo]
    _(scopes.values.flatten.map(&:user_id).uniq).must_equal [admin.id]
    _(scopes.values.flatten.map(&:id) & Planner::Item.trashed.pluck(:id)).must_be_empty
    _(Core::Modules.linkable_kinds.map(&:new_route)).must_equal %i[new_planner_event_path new_planner_task_path new_planner_todo_path]
  end

  it "tells where each kind lives: its page and view around the record, by default" do
    sample = {"event" => :dentist, "task" => :pay_rent_task, "todo" => :water_plants_todo}
    paths = Core::Modules.linkable_kinds.to_h { |kind| [kind.key, kind.home.call(planner_items(sample.fetch(kind.key)))] }
    _(paths["event"]).must_equal "/planner/calendar?date=2026-10-07&view=day"
    _(paths["task"]).must_equal "/planner/schedule?date=2026-10-07&view=day"
    _(paths["todo"]).must_equal "/planner/todos"
    I18n.with_locale(:en) do
      _(Core::Modules.linkable_kinds.map { |kind| I18n.t(kind.home_label_key) }).must_equal ["Show in Calendar", "Show in Schedule", "Show in Todos"]
    end
  end

  it "tells in which dialog each kind opens" do
    _(Core::Modules.linkable_kinds.map(&:dialog_frame).uniq).must_equal ["item-dialog-frame"]
    _(Core::LinkableKind.dialog_frame_of(planner_items(:dentist))).must_equal "item-dialog-frame"
  end

  it "has Core first, then Planner" do
    _(Core::Modules.all.map(&:name)).must_equal %w[core planner]
  end

  it "feeds the setup runner, administrator step first" do
    _(Core::Setup::Runner.default_steps.first).must_be_instance_of Core::Setup::AdminStep
  end

  it "lays the sidebar out as Home, the Planner, then Admin; Preferences sits at the bottom" do
    _(Core::Modules.navigation(admin: false).map(&:route)).must_equal %i[root_path planner_calendar_path planner_agenda_path planner_important_events_path planner_missed_events_path planner_schedule_path planner_forgotten_tasks_path planner_todos_path]
    _(Core::Modules.navigation(admin: true).map(&:route)).must_equal %i[root_path planner_calendar_path planner_agenda_path planner_important_events_path planner_missed_events_path planner_schedule_path planner_forgotten_tasks_path planner_todos_path admin_users_path admin_theme_path]
    [false, true].each do |admin|
      _(Core::Modules.navigation(admin:, placement: :footer).map(&:route)).must_equal %i[edit_preferences_path trash_path]
    end
  end

  it "gives members no admin navigation and admins Users" do
    _(Core::Modules.navigation(admin: false).map(&:route)).wont_include :admin_users_path
    _(Core::Modules.navigation(admin: true).map(&:route)).must_include :admin_users_path
  end
end

describe "the trash in the manifests" do
  before do
    @saved = Core::Modules.all
    Core::Modules.reset!
  end

  after do
    Core::Modules.reset!
    @saved.each { |manifest| Core::Modules.register(manifest) }
  end

  def source(total, title_key: "planner.nav.groups.planner")
    Core::TrashSource.new(title_key:, route: :planner_trash_path, counts: ->(_user) { {"event" => total} }, total: ->(_user) { total }, labels_key: "planner.trash.counts")
  end

  it "collects the sources of the modules that have a trash, in registration order" do
    one = source(2)
    two = source(5, title_key: "core.nav.home")
    Core::Modules.register(Core::ModuleManifest.new(name: "a", trash: one))
    Core::Modules.register(Core::ModuleManifest.new(name: "none"))
    Core::Modules.register(Core::ModuleManifest.new(name: "b", trash: two))
    _(Core::Modules.trash_sources).must_equal [one, two]
  end

  it "adds up what every source holds for a user" do
    Core::Modules.register(Core::ModuleManifest.new(name: "a", trash: source(2)))
    Core::Modules.register(Core::ModuleManifest.new(name: "b", trash: source(5)))
    _(Core::Modules.trash_total(users(:admin))).must_equal 7
  end

  it "has no total without sources" do
    _(Core::Modules.trash_total(users(:admin))).must_equal 0
  end
end

describe "the booted trash" do
  it "is the Planner's, counting the signed-in user's own items" do
    _(Core::Modules.trash_sources.size).must_equal 1
    _(Core::Modules.trash_total(users(:admin))).must_equal 4
    _(Core::Modules.trash_total(users(:member))).must_equal 0
  end
end
