# What a module tells Core about one kind of record that can be linked.
#
# key: unique across modules, the word that travels in requests.
# label_key: the locale key of the kind's name, with one/other forms.
# scope: user -> the user's kept records of the kind. Its table has a `title`
# column, which is what the picker searches.
# new_route: the path helper of the kind's new form, or nil when the kind
# cannot be created from a record.
# home: record -> the address of the page and view that hold the record, and
# home_label_key names it ("Show in Calendar"). A link leads there.
# dialog_frame: the id of the Turbo Frame that shows a record of the kind in a
# dialog, on the pages that have one. A link aimed at it opens the record
# there.
Core::LinkableKind = Data.define(:key, :label_key, :scope, :new_route, :home, :home_label_key, :dialog_frame) do
  def initialize(key:, label_key:, scope:, new_route: nil, home: nil, home_label_key: nil, dialog_frame: nil) = super

  # [what to say, where it leads] for a record, or nil when its kind does not
  # say where it lives.
  def self.home_of(record)
    kind = Core::Modules.linkable_kind(record.for_links.kind)
    [I18n.t(kind.home_label_key), kind.home.call(record)] if kind&.home && kind.home_label_key
  end

  # The frame to aim a link to the record at, or nil when its kind has none.
  def self.dialog_frame_of(record) = Core::Modules.linkable_kind(record.for_links.kind)&.dialog_frame
end
