import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // daisyUI's .modal fills the viewport, so a click on the dialog itself is a click on the backdrop
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
