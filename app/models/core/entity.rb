# The identity every user-facing record shares, whatever its module: owner,
# kind and, once records can be trashed, whether it is in the trash.
#
# A record's table shares its primary key.
class Core::Entity < ApplicationRecord
  include Core::SoftDeletable

  belongs_to :user
  belongs_to :record, polymorphic: true, foreign_key: :id, foreign_type: :record_type, optional: true
end
