# What a record says about itself on the Links pages.
#
# kind: the record's kind, a key of the manifest.
# label: the record's name in a list or a sentence.
# status: a word for what the record is not plain "active", or nil.
# day: the day the record belongs to, when it has one of its own, or nil.
Core::LinkedEntityFacts = Data.define(:kind, :label, :status, :day)
