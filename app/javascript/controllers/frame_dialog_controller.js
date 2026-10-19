import { Controller } from "@hotwired/stimulus"

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
