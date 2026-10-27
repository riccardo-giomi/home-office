class Core::UI::ButtonComponent < ApplicationComponent
  SIZES = {xs: "btn-xs", sm: "btn-sm"}.freeze
  VARIANTS = {
    primary: "btn-primary",
    secondary: "bg-base-100 border-base-300 hover:bg-base-300",
    ghost: "btn-ghost",
    danger: "btn-error"
  }.freeze

  # With href: it is a link drawn as a button (it goes somewhere), without it
  # really is a button (it does something).
  #
  # size: :xs and square: true make it small and icon-only (24 px, the least a
  # target may be).
  #
  # class: classes added to the button's own. A button with a long text needs
  # `max-w-full` to be able to shrink.
  def initialize(variant: :primary, type: :button, href: nil, size: nil, square: false, **html_options)
    @variant = variant
    @size = size
    @square = square
    @href = href
    @type = type
    @extra_classes = html_options.delete(:class)
    @html_options = html_options
  end

  def call
    classes = [
      "btn", VARIANTS.fetch(@variant),
      (SIZES.fetch(@size) if @size),
      ("btn-square" if @square),
      @extra_classes
    ].compact

    return link_to(content, @href, class: classes, **@html_options) if @href

    tag.button(content, type: @type, class: classes, **@html_options)
  end
end
