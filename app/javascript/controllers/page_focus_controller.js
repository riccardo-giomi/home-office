import { Controller } from "@hotwired/stimulus"
import { focusPageStart } from "controllers/page_start"

// Turbo leaves focus on <body> after a visit: put it where the new page starts. Not on the first
// load, not on morphs, and not when the page asks for focus itself (autofocus: the error summary).
export default class extends Controller {
  connect() {
    this.focusPage = (event) => {
      if (event.detail?.renderMethod === "morph" || document.querySelector("[autofocus]")) return

      focusPageStart()
    }
    document.addEventListener("turbo:render", this.focusPage)
  }

  disconnect() {
    document.removeEventListener("turbo:render", this.focusPage)
  }
}
