Core::Manifest = Core::ModuleManifest.new(
  name: "core",
  navigation: [
    Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home),
    Core::NavItem.new(label_key: "core.nav.preferences", route: :edit_preferences_path, icon: :cog, placement: :footer),
    Core::NavItem.new(label_key: "core.nav.users", route: :admin_users_path, icon: :users, group_key: "core.nav.groups.admin", admin: true),
    Core::NavItem.new(label_key: "core.nav.theme", route: :admin_theme_path, icon: :swatch, group_key: "core.nav.groups.admin", admin: true)
  ],
  setup_steps: [Core::Setup::AdminStep.new]
)
