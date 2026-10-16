# pagy's series nav (labeled <nav>, aria-current on the current page) dressed as daisyUI buttons.
# Everything is styled from here, so views never carry raw classes.
class Core::UI::PaginationComponent < ApplicationComponent
  # Five page links and two arrows still fit a 320 px screen
  SLOTS = 5

  CLASSES = [
    "mt-4",
    "[&_nav]:join",
    "[&_a]:join-item [&_a]:btn [&_a]:btn-sm [&_a]:min-w-8",
    "[&_a[aria-current=page]]:btn-active [&_a[aria-current=page]]:text-base-content [&_a[aria-current=page]]:underline",
    "[&_a[aria-disabled=true]:not([aria-current])]:btn-disabled"
  ].join(" ").freeze

  # Never pass a label that came from a user, #call renders it as html_safe
  def initialize(pagy:, label:)
    @pagy = pagy
    @label = label
  end

  def render? = @pagy.last > 1

  def call
    tag.div(@pagy.series_nav(aria_label: @label, slots: SLOTS).html_safe, class: CLASSES)
  end
end
