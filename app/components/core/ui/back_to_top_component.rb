# A button in the sticky header that takes the visitor back to the start of a
# long page.
#
# It is invisible until the page heading has gone under the header, which is
# when the controls under the heading are leaving the screen. Invisible,
# not hidden: it keeps its space, so the header does not move when it shows,
# and it is out of the tab order and the accessibility tree meanwhile. A script
# shows and hides it.
#
# shown draws it visible and without the script, for previews.
class Core::UI::BackToTopComponent < ApplicationComponent
  def initialize(shown: false)
    @shown = shown
  end

  def call
    tag.button(type: "button", class: ["btn btn-ghost btn-square", ("invisible" unless @shown)],
      data: ({controller: "back-to-top", action: "back-to-top#go"} unless @shown)) do
      safe_join([render(Core::UI::IconComponent.new(name: :arrow_up)), tag.span(t("core.ui.back_to_top.label"), class: "sr-only")])
    end
  end
end
