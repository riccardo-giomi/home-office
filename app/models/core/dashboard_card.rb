# A card of the home page.
#
# `title_key` and `total_key` are locale keys, and the view translates them
# (`total_key` is pluralized with `total`).
# `href` is where the title links to, `narrow_href` where it links to below 640
# px, and `lines` are Core::DashboardLine entries.
# The card holds only keys and numbers; the view writes the text.
Core::DashboardCard = Data.define(:title_key, :href, :narrow_href, :total, :total_key, :lines) do
  def initialize(title_key:, href:, lines:, narrow_href: nil, total: nil, total_key: nil) = super
end
