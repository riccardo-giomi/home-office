# One line of a card: a count and a label.
#
# `label_key` is a locale key, pluralized with `count`.
# `href` is where the line links to and `narrow_href` where it links to below
# 640 px.
Core::DashboardLine = Data.define(:label_key, :count, :href, :narrow_href) do
  def initialize(label_key:, count:, href:, narrow_href: nil) = super
end
