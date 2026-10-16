# What a module tells Core about itself, so Core never edits to add a module.
Core::ModuleManifest = Data.define(:name, :navigation, :setup_steps) do
  def initialize(name:, navigation: [], setup_steps: []) = super
end
