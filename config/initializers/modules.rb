Rails.application.config.to_prepare do
  Core::Modules.reset!
  Core::Modules.register(Core::Manifest)
  Core::Modules.register(Planner::Manifest)
end
