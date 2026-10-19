import { Controller } from "@hotwired/stimulus"

// When the page is shown (a visit, not a refresh) it scrolls to the current
// time, centered, if today is among the days, else to 7:00 at the top.
export default class extends Controller {
  static values = { mode: String }

  connect() {
    requestAnimationFrame(() => this.scroll())
  }

  scroll() {
    if (this.modeValue === "now") {
      this.element
        .querySelector("[data-controller~=now-marker]")
        ?.scrollIntoView({ block: "center" })
    } else {
      this.element
        .querySelector("[data-hour='7']")
        ?.scrollIntoView({ block: "start" })
    }
  }
}
