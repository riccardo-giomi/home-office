# Previews and setup steps arrive with the features that build them.
Planner::Manifest = Core::ModuleManifest.new(
  name: "planner",
  navigation: [
    Core::NavItem.new(label_key: "planner.nav.calendar",
      route: :planner_calendar_path, icon: :calendar,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.events"),
    Core::NavItem.new(label_key: "planner.nav.agenda",
      route: :planner_agenda_path, icon: :list,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.events"),
    Core::NavItem.new(label_key: "planner.nav.important_events",
      route: :planner_important_events_path, icon: :warning,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.events",
      badge: ->(user) { Planner::Counts.for(user).important },
      badge_label_key: "planner.nav.important_events_badge"),
    Core::NavItem.new(label_key: "planner.nav.missed_events",
      route: :planner_missed_events_path, icon: :warning,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.events",
      badge: ->(user) { Planner::Counts.for(user).missed },
      badge_label_key: "planner.nav.missed_events_badge"),
    Core::NavItem.new(label_key: "planner.nav.schedule",
      route: :planner_schedule_path, icon: :checklist,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.tasks"),
    Core::NavItem.new(label_key: "planner.nav.forgotten_tasks",
      route: :planner_forgotten_tasks_path, icon: :warning,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.tasks",
      badge: ->(user) { Planner::Counts.for(user).forgotten },
      badge_label_key: "planner.nav.forgotten_tasks_badge"),
    Core::NavItem.new(label_key: "planner.nav.todos",
      route: :planner_todos_path, icon: :queue_list,
      group_key: "planner.nav.groups.planner",
      subgroup_key: "planner.nav.subgroups.todos")
  ],
  purge: ->(now) { Planner::Series.purge_expired(now) },
  catch_up: lambda do |user, today|
    Planner::CatchUp.run(user, today:) if Planner::CatchUp.lazy?
  end,
  dashboard: ->(user, today) { Planner::Dashboard.cards(user, today) },
  mcp_tools: [Planner::Mcp::ListItems, Planner::Mcp::GetItem],
  mcp_overview: ->(user, today) { Planner::Mcp::Overview.call(user, today) },
  trash: Core::TrashSource.new(
    title_key: "planner.nav.groups.planner",
    route: :planner_trash_path,
    labels_key: "planner.trash.counts",
    counts: ->(user) { Planner::Trash.new(user).counts },
    total: ->(user) { Planner::Trash.new(user).total },
    kind_path: lambda do |kind|
      Rails.application.routes.url_helpers.planner_trash_path(type: kind)
    end,
    kinds_key: "planner.trash.kinds"
  ),
  linkable_kinds: %w[event task todo].map do |key|
    klass = Planner::Item.sti_class_for("Planner::#{key.camelize}")
    routes = Rails.application.routes.url_helpers
    # Default URIs for Items.
    #
    # Each address carries `at=<id>`, so the target page shows that record.
    #
    # A todo has no view or date, it simply defaults to the todos page.
    homes = {
      "event" => ->(item) { routes.planner_calendar_path(view: "day", date: item.day.iso8601, at: item.reveal_key) },
      "task" => ->(item) { routes.planner_schedule_path(view: "day", date: item.day.iso8601, at: item.reveal_key) },
      "todo" => ->(item) { routes.planner_todos_path(at: item.reveal_key) }
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
