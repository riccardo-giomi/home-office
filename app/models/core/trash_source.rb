# What a module tells Core about its trash.
#
# counts: takes a user, answers an ordered hash of kind => how many (zeros
# included).
# total: takes a user, answers one number. It is a cheap query, because the
# sidebar asks on every page.
# labels_key: where the line for a kind lives ("<labels_key>.<kind>", pluralized
# on count).
Core::TrashSource = Data.define(:title_key, :route, :counts, :total, :labels_key)
