import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A dialog that shows what a link loads into its Turbo Frame.
//
// It opens once the frame has loaded something, empties the frame when it
// closes and closes on a click on the backdrop.
//
// The browser handles the focus trap, Escape and returning focus.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  // Closes the dialog when the page is about to be cached, so that the copy
  // never comes back with the dialog open but not modal.
  //
  // A refresh, which is what a change made in the dialog asks for, is not
  // cached (shouldCacheSnapshot is false), although Turbo still announces it
  // with turbo:before-cache. The dialog stays open then.
  beforeCache() {
    if (Turbo.session.navigator.currentVisit?.shouldCacheSnapshot === false)
      return

    this.close()
  }

  emptied() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.removeAttribute("complete")
    this.frameTarget.innerHTML = ""
  }

  // daisyUI's .modal fills the viewport, so a click on the dialog itself is a
  // click on the backdrop.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
