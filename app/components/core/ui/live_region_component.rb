# One persistent region: later sections announce changes by updating it with a Turbo Stream.
# visible: draws it on screen (previews only); on a real page it is for screen readers alone.
class Core::UI::LiveRegionComponent < ApplicationComponent
  def initialize(visible: false)
    @visible = visible
  end

  def call
    tag.div(content, id: "announcements", class: (@visible ? "alert alert-soft alert-info" : "sr-only"), role: "status", aria: {live: "polite", atomic: true}, data: {turbo_permanent: true})
  end
end
