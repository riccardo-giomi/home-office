import { Controller } from "@hotwired/stimulus"

// When the page is shown (a visit, not a refresh) in the "now" mode, it
// scrolls to the current time, centered. In any other mode it stays where the
// browser puts it.
export default class extends Controller {
  static values = { mode: String }

  connect() {
    requestAnimationFrame(() => this.scroll())
  }

  // The line places itself when its own controller connects, which can be
  // after this one (modules load one by one). Until then it is invisible and
  // not where it will be, so wait for it, for a second at most.
  scroll(attempt = 0) {
    if (this.modeValue !== "now") return

    const line = this.element.querySelector("[data-controller~=now-line]")
    if (line?.classList.contains("invisible") && attempt < 60) {
      requestAnimationFrame(() => this.scroll(attempt + 1))
      return
    }
    line?.scrollIntoView({ block: "center" })
  }
}
