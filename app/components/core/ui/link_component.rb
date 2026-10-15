class Core::UI::LinkComponent < ApplicationComponent
  # min-h-6/min-w-6: WCAG 2.5.8 asks for targets of at least 24x24 CSS px
  def initialize(href:, **html_options)
    @href = href
    @html_options = html_options
  end

  def call
    link_to(content, @href, class: "link inline-flex items-center min-h-6 min-w-6", **@html_options)
  end
end
