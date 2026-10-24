require "test_helper"

class Core::NavigationHelperTest < ActionView::TestCase
  tests Core::NavigationHelper

  before do
    @saved = Core::Modules.all
    Core::Modules.reset!
    Current.session = Session.new(user: users(:admin))
  end

  after do
    Core::Modules.reset!
    @saved.each { |manifest| Core::Modules.register(manifest) }
    Current.reset
  end

  def register(*items) = Core::Modules.register(Core::ModuleManifest.new(name: "test", navigation: items, setup_steps: []))

  def root_path = "/"

  def items = navigation_groups.flat_map(&:items)

  it "gives an item no badge unless its manifest entry has a count" do
    register Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home)
    _(items.map(&:badge)).must_equal [nil]
  end

  it "asks the entry for the signed-in user's count and words it with the count" do
    asked = []
    register Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home,
      badge: ->(user) { asked << user.id && 3 }, badge_label_key: "core.nav.trash_badge")
    badge = items.first.badge
    _(badge.count).must_equal 3
    _(badge.label).must_equal "3 items in the trash"
    _(asked).must_equal [users(:admin).id]
  end

  it "says one item in the singular" do
    register Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home, badge: ->(_) { 1 }, badge_label_key: "core.nav.trash_badge")
    _(items.first.badge.label).must_equal "1 item in the trash"
  end
end
