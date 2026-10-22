class Core::UI::PriorityComponentPreview < ViewComponent::Preview
  WORDS = {low: "Low priority", normal: "Normal priority", high: "High priority", urgent: "Urgent priority"}.freeze

  # The scale on both themes at a size that can be judged: normal is silent in
  # lists, so it is forced here.
  class Scale < ViewComponent::Base
    def initialize(compact: false)
      @compact = compact
    end

    def call
      safe_join(%w[light dark].map { |theme|
        tag.div(class: "flex flex-wrap items-center gap-4 bg-base-100 p-6 text-base-content", data: {theme:}) do
          safe_join([tag.span(theme, class: "w-12 font-mono text-sm")] + WORDS.map { |level, label|
            render(Core::UI::PriorityComponent.new(level:, label:, compact: @compact, always: true))
          })
        end
      })
    end
  end

  def scale = render(Scale.new)

  # Inside a grid card: the icon only, the word hidden for the eye and spoken.
  def compact_scale = render(Scale.new(compact: true))

  def low = render(priority(:low, "Low priority"))

  def normal = render(priority(:normal, "Normal priority", always: true))

  def high = render(priority(:high, "High priority"))

  def urgent = render(priority(:urgent, "Urgent priority"))

  private

  def priority(level, label, **options) = Core::UI::PriorityComponent.new(level:, label:, **options)
end
