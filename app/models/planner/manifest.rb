# Navigation, trash and more arrive with the features that build them.
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
  ]
)
