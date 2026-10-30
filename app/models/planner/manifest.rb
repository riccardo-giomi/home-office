# Previews and setup steps arrive with the features that build them.
Planner::Manifest = Core::ModuleManifest.new(
  name: "planner",
  navigation: [
    Core::NavItem.new(label_key: "planner.nav.calendar",
      route: :planner_calendar_path, icon: :calendar,
      group_key: "planner.nav.groups.planner"),
    Core::NavItem.new(label_key: "planner.nav.agenda",
      route: :planner_agenda_path, icon: :list,
      group_key: "planner.nav.groups.planner"),
    Core::NavItem.new(label_key: "planner.nav.schedule",
      route: :planner_schedule_path, icon: :checklist,
      group_key: "planner.nav.groups.planner"),
    Core::NavItem.new(label_key: "planner.nav.todos",
      route: :planner_todos_path, icon: :queue_list,
      group_key: "planner.nav.groups.planner")
  ],
  purge: ->(now) { Planner::Series.purge_expired(now) },
  trash: Core::TrashSource.new(
    title_key: "planner.nav.groups.planner",
    route: :planner_trash_path,
    labels_key: "planner.trash.counts",
    counts: ->(user) { Planner::Trash.new(user).counts },
    total: ->(user) { Planner::Trash.new(user).total }
  ),
  linkable_kinds: %w[event task todo].map do |key|
    klass = Planner::Item.sti_class_for("Planner::#{key.camelize}")
    routes = Rails.application.routes.url_helpers
    # The page around the record's day, in the view every device has (the day).
    # A todo has no day: its list is the page.
    homes = {
      "event" => ->(item) { routes.planner_calendar_path(view: "day", date: item.day.iso8601) },
      "task" => ->(item) { routes.planner_schedule_path(view: "day", date: item.day.iso8601) },
      "todo" => ->(_item) { routes.planner_todos_path }
    }
    Core::LinkableKind.new(
      key:,
      label_key: "planner.link_kinds.#{key}",
      scope: ->(user) { klass.owned_by(user).kept },
      new_route: :"new_planner_#{key}_path",
      home: homes.fetch(key),
      home_label_key: "planner.link_homes.#{key}",
      dialog_frame: Planner::ItemDialog::FRAME_ID
    )
  end
)
