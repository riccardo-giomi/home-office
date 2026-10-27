class Core::UI::EntryStripPreview < ViewComponent::Preview
  # A page of several entries, which the Theme page cannot show inside its own
  # sections: it leaves it out
  def self.page_level? = true

  # The line at the top at several widths of the same entry: the words go
  # first, then every chip but the first
  def widths
    render_with_template(template: "core/ui/entry_strip_preview/widths", locals: {statuses: STATUSES, cases: WIDTHS})
  end

  STATUSES = [{icon: :minus_circle, label: "Abandoned"}, {priority: :urgent, label: "Urgent priority"}].freeze

  WIDTHS = [
    {name: "Wide (18rem)", size: "w-72", compact: false},
    {name: "Just wide enough for the words (14.5rem)", size: "w-60", compact: false},
    {name: "Just too narrow for the words (13.5rem)", size: "w-56", compact: false},
    {name: "Narrow (9.5rem)", size: "w-40", compact: false},
    {name: "Very narrow (7.5rem): only the first status", size: "w-32", compact: false},
    {name: "Compact (9.5rem)", size: "w-40", compact: true}
  ].freeze
end
