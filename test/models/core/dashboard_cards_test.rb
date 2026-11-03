require "test_helper"

describe Core::Modules do
  let(:user) { users(:admin) }

  it "gives the modules' cards in manifest order, then the Trash card, always last" do
    cards = Core::Modules.dashboard_cards(user, today: Date.current)
    _(cards.map(&:title_key)).must_equal %w[planner.dashboard.events.title planner.dashboard.tasks.title planner.dashboard.todos.title core.dashboard.trash.title]
  end

  it "has a Trash card with its total and a line for every kind, zeros included, each to its tab" do
    trash = Core::Modules.dashboard_cards(user, today: Date.current).last
    _(trash.href).must_equal Rails.application.routes.url_helpers.trash_path
    _(trash.total).must_equal Planner::Trash.new(user).total
    _(trash.lines.map(&:href)).must_equal %w[event task todo].map { |kind| Rails.application.routes.url_helpers.planner_trash_path(type: kind) }
    _(trash.lines.map(&:count)).must_equal Planner::Trash.new(user).counts.values
  end

  it "has no Trash card when no module keeps a trash" do
    saved = Core::Modules.all
    Core::Modules.reset!
    Core::Modules.register(Core::ModuleManifest.new(name: "bare"))
    _(Core::Modules.dashboard_cards(user, today: Date.current)).must_be :empty?
  ensure
    Core::Modules.reset!
    saved.each { |manifest| Core::Modules.register(manifest) }
  end
end
