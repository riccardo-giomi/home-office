# A counter beside a label (menu link, button).
#
# It renders only when `count` is a positive number. The number is text and is
# capped at 99 (shown as 99+) so it cannot overflow; the `label` for screen
# readers says what is counted.
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
