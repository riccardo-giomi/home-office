# shown: draws it as it looks without JavaScript (previews only)
class Core::UI::NoscriptNoticeComponent < ApplicationComponent
  def initialize(shown: false)
    @shown = shown
  end

  def visibility = @shown ? "flex" : "hidden noscript:flex"
end
