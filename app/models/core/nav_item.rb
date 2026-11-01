Core::NavItem = Data.define(
  :label_key, :route, :icon, :group_key, :admin, :placement, :badge, :badge_label_key
) do
  # placement: :main (the top of the sidebar) or :footer (beside the account box
  # at the bottom).
  #
  # badge: a callable that takes the user and returns a number. The entry
  # shows a counter with that number beside its label when the number is
  # above zero.
  #
  # badge_label_key: words it for readers, with `count`.
  def initialize(
    label_key:, route:, icon:, group_key: nil, admin: false, placement: :main,
    badge: nil, badge_label_key: nil
  ) = super
end
