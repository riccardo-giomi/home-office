# What a module tells Core about itself, so Core never edits to add a module.
Core::ModuleManifest = Data.define(:name, :navigation, :setup_steps, :trash) do
  # trash: a Core::TrashSource, when the module keeps things in a trash.
  def initialize(name:, navigation: [], setup_steps: [], trash: nil) = super
end
