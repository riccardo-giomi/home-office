# A count beside a label (a menu link, a button) for a view that holds
# exceptions: it shows only when there is something in it. The number is text,
# the spoken label says what is counted, and it stops at 99+.
class Core::UI::BadgeComponent < ApplicationComponent
  CAP = 99

  def initialize(count:, label:)
    @count = count
    @label = label
  end

  def render? = @count.to_i.positive?

  def call
    tag.span(class: "badge badge-neutral badge-sm ms-2 font-semibold") do
      safe_join([tag.span((@count > CAP) ? "#{CAP}+" : @count, "aria-hidden": "true"), tag.span(@label, class: "sr-only")])
    end
  end
end
