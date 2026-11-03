# What a module tells Core about its trash.
#
# counts: takes a user, answers an ordered hash of kind => how many (zeros
# included).
# total: takes a user, answers one number. It is a cheap query, because the
# sidebar asks on every page.
# labels_key: where the line for a kind lives ("<labels_key>.<kind>", pluralized
# on count).
#
# kind_path: takes a kind and returns the path of the list of that kind.
# kinds_key is the locale key of the name of a kind ("<kinds_key>.<kind>",
# pluralized with the count). The Trash card of the home page uses both to link
# each kind.
Core::TrashSource = Data.define(:title_key, :route, :counts, :total, :labels_key, :kind_path, :kinds_key) do
  def initialize(title_key:, route:, counts:, total:, labels_key:, kind_path: nil, kinds_key: nil) = super
end
