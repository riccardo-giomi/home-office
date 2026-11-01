Core::NavItem = Data.define(
  :label_key, :route, :icon, :group_key, :admin, :placement, :badge,
  :badge_label_key, :subgroup_key
) do
  # placement: :main (the top of the sidebar) or :footer (beside the account box
  # at the bottom).
  #
  # badge: a callable that takes the user and returns a number. The entry
  # shows a counter with that number beside its label when the number is
  # above zero.
  #
  # badge_label_key: words it for readers, with `count`.
  #
  # subgroup_key: key of a heading drawn above a run of consecutive items of the
  # group that have the same key. The heading is plain text. An item without a
  # subgroup_key has no heading.
  def initialize(
    label_key:, route:, icon:, group_key: nil, admin: false, placement: :main,
    badge: nil, badge_label_key: nil, subgroup_key: nil
  ) = super
end
