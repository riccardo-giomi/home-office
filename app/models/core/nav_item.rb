Core::NavItem = Data.define(:label_key, :route, :icon, :group_key, :admin, :placement) do
  # placement: :main (the top of the sidebar) or :footer (beside the account box at the bottom)
  def initialize(label_key:, route:, icon:, group_key: nil, admin: false, placement: :main) = super
end
