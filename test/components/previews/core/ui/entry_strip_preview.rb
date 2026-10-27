class Core::UI::EntryStripPreview < ViewComponent::Preview
  # A page of several entries, which the Theme page cannot show inside its own
  # sections: it leaves it out
  def self.page_level? = true

  # The line at the top at several widths of the same entry: the words go
  # first, then every chip but the first
  def widths
    render_with_template(template: "core/ui/entry_strip_preview/widths", locals: {statuses: STATUSES, cases: WIDTHS})
  end

  # The same, with the number of links and the button that sets a record aside,
  # in the sizes of card an entry can find itself in
  def options
    render_with_template(template: "core/ui/entry_strip_preview/options", locals: {cases: OPTIONS})
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

  LINKS = [{icon: :link, label: "2 links", count: 2}].freeze
  EVERY_STATUS = [{icon: :minus_circle, label: "Abandoned"}, {priority: :urgent, label: "Urgent priority"}, {icon: :link, label: "12 links", count: 12}].freeze

  OPTIONS = [
    {name: "Full, with a check", size: "w-72", check: true, pin: true, title: "Pay the rent", statuses: LINKS},
    {name: "Full, every status", size: "w-72", check: true, pin: true, title: "Review the plan", statuses: EVERY_STATUS},
    {name: "Full, no check, no pin", size: "w-72", check: false, pin: false, title: "Dentist", statuses: LINKS},
    {name: "Narrow (9.5rem)", size: "w-40", check: true, pin: true, title: "Dentist, Wednesday", statuses: EVERY_STATUS},
    {name: "Compact, without the pin", size: "w-40", check: false, pin: false, title: "Dentist", compact: true, statuses: LINKS},
    {name: "Compact, 30 minute box (cut to its height)", size: "w-40 h-14 overflow-hidden", check: false, pin: false, title: "Dentist", compact: true, statuses: EVERY_STATUS}
  ].freeze
end
