# What a module tells Core about itself, so Core never edits to add a module.
Core::ModuleManifest = Data.define(:name, :navigation, :setup_steps, :trash, :linkable_kinds) do
  # trash: a Core::TrashSource, when the module keeps things in a trash.
  # linkable_kinds: Core::LinkableKind entries, one for each kind of record
  # the module lets a person link.
  def initialize(name:, navigation: [], setup_steps: [], trash: nil, linkable_kinds: []) = super
end
