# What a module tells Core about itself, so Core never edits to add a module.
Core::ModuleManifest = Data.define(:name, :navigation, :setup_steps, :trash, :linkable_kinds, :purge) do
  # trash: a Core::TrashSource, when the module keeps things in a trash.
  # linkable_kinds: Core::LinkableKind entries, one for each kind of record
  # the module lets a person link.
  # purge: a callable that takes the moment, for what the module keeps in the
  # trash outside the entities. It runs before the entities are purged.
  def initialize(name:, navigation: [], setup_steps: [], trash: nil, linkable_kinds: [], purge: nil) = super
end
