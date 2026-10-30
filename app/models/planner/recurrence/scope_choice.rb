# Which events of a series are going to be changed by an edit or a delete
# (`apply[scope]`).
#
# This one, this and the ones after it, this and the ones before it (delete
# only), or all of them.
class Planner::Recurrence::ScopeChoice
  include ActiveModel::Model
  include ActiveModel::Attributes

  EDIT = %w[this following all].freeze
  DELETE = %w[this following past all].freeze

  attribute :scope, :string, default: "this"

  def self.model_name = ActiveModel::Name.new(self, nil, "Apply")

  # What the request asked for, as long as it is one of `allowed`.
  #
  # Otherwise the safest: this event only.
  def self.of(value, allowed: EDIT) = new(scope: (value if allowed.include?(value)) || "this")
end
