# A native <dialog> that shows pages loaded into a Turbo Frame.
#
# A link with data-turbo-frame="<frame_id>" opens the page it points to over
# the current one, which stays exactly as it was (scroll, view, date).
#
# The browser provides the focus trap, Escape and the return of focus to the
# link that was used.
# The page loaded in must hold a frame with the same id and a heading with
# id="dialog-title".
class Core::UI::FrameDialogComponent < ApplicationComponent
  # open: only for previews (it draws the dialog open without the browser's
  # modal behavior).
  def initialize(id:, frame_id:, open: false)
    @id = id
    @frame_id = frame_id
    @open = open
  end
end
