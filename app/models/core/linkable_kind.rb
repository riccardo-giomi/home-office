# What a module tells Core about one kind of record that can be linked.
#
# key: unique across modules, the word that travels in requests.
# label_key: the locale key of the kind's name, with one/other forms.
# scope: user -> the user's kept records of the kind. Its table has a `title`
# column, which is what the picker searches.
# new_route: the path helper of the kind's new form, or nil when the kind
# cannot be created from a record.
Core::LinkableKind = Data.define(:key, :label_key, :scope, :new_route)
