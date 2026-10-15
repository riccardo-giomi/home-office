class Core::UI::SkipLinkComponent < ApplicationComponent
  def initialize(target:, **html_options)
    @target = target
    @html_options = html_options
  end

  def call
    link_to(t("core.ui.skip_link"), "##{@target}",
      class: "btn btn-primary sr-only focus:not-sr-only focus:absolute focus:start-2 focus:top-2 focus:z-50",
      data: {controller: "focus-link", action: "focus-link#focus"}, **@html_options)
  end
end
