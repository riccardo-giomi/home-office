import { Turbo } from "@hotwired/turbo-rails"

// <turbo-stream action="close_dialog" target="dialog-id">: the server closes a
// dialog once a change has been made in it.
Turbo.StreamActions.close_dialog = function () {
  this.targetElements.forEach((dialog) => {
    if (dialog.open) dialog.close()
  })
}
