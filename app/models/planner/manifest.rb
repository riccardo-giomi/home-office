# Navigation, trash and more arrive with the features that build them
Planner::Manifest = Core::ModuleManifest.new(
  name: "planner",
  navigation: [
    Core::NavItem.new(label_key: "planner.nav.events",
      route: :planner_events_path, icon: :calendar)
  ]
)
