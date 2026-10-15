# The row of actions under a page's heading: the main action at the start (new thing), at the other end the
# way to another view of the same thing (list or calendar). A plain group, not role="toolbar", which would
# promise arrow-key navigation inside it.
class Core::UI::PageToolbarComponent < ApplicationComponent
  renders_one :leading
  renders_one :trailing

  def call
    tag.div(safe_join([leading, trailing].compact), class: "mb-4 flex flex-wrap items-center justify-between gap-2")
  end
end
