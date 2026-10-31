# What a module tells Core about itself, so Core never edits to add a module.
Core::ModuleManifest = Data.define(
  :name, :navigation, :setup_steps, :trash, :linkable_kinds, :purge,
  :catch_up
) do
  # trash: a Core::TrashSource, when the module keeps things in a trash.
  # linkable_kinds: Core::LinkableKind entries, one for each kind of record
  # the module lets a person link.
  # purge: a callable that takes the moment, for what the module keeps in the
  # trash outside the entities. It runs before the entities are purged.
  #
  # catch_up: a callable that takes the signed-in user and today's date. Core
  # calls it on the requests of a signed-in user, so that a module can update
  # what depends on the date.
  def initialize(
    name:, navigation: [], setup_steps: [], trash: nil, linkable_kinds: [],
    purge: nil, catch_up: nil
  ) = super
end
