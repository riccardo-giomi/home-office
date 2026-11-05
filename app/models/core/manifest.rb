Core::Manifest = Core::ModuleManifest.new(
  name: "core",
  navigation: [
    Core::NavItem.new(label_key: "core.nav.home", route: :root_path, icon: :home),
    Core::NavItem.new(label_key: "core.nav.settings", route: :settings_path, icon: :cog, placement: :footer),
    Core::NavItem.new(label_key: "core.nav.trash", route: :trash_path, icon: :trash, placement: :footer,
      badge: ->(user) { Core::Modules.trash_total(user) }, badge_label_key: "core.nav.trash_badge"),
    Core::NavItem.new(label_key: "core.nav.users", route: :admin_users_path, icon: :users, group_key: "core.nav.groups.admin", admin: true),
    Core::NavItem.new(label_key: "core.nav.theme", route: :admin_theme_path, icon: :swatch, group_key: "core.nav.groups.admin", admin: true)
  ],
  setup_steps: [Core::Setup::AdminStep.new]
)
