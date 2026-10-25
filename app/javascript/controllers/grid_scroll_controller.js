import { Controller } from "@hotwired/stimulus"

// When the page is shown (a visit, not a refresh) in the "now" mode, it
// scrolls to the current time, centered. In any other mode it stays where the
// browser puts it.
export default class extends Controller {
  static values = { mode: String }

  connect() {
    requestAnimationFrame(() => this.scroll())
  }

  scroll() {
    if (this.modeValue !== "now") return

    this.element
      .querySelector("[data-controller~=now-marker]")
      ?.scrollIntoView({ block: "center" })
  }
}
