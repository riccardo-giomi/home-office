import { Controller } from "@hotwired/stimulus"
import { focusPageStart } from "controllers/page_start"

// The control will appear when we scroll past the heading (css: "main h1"),
// this is a distance used as a fallback when there is no heading available.
const WITHOUT_HEADING = 200

// Shows the button once the page heading has gone under the sticky header,
// which is when the controls below it (the toolar, the period navigation)
// are leaving the screen too.
//
// The jump is instant: there is no animation to tone down for people who ask
// for less motion. Focus follows to the page heading, as after a visit.
export default class extends Controller {
  connect() {
    this.update = () =>
      this.element.classList.toggle("invisible", !this.pastHeading())
    window.addEventListener("scroll", this.update, { passive: true })
    // A refresh in place (morph) gives the button back the server's class,
    // and does not connect it again
    document.addEventListener("turbo:render", this.update)
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.update)
    document.removeEventListener("turbo:render", this.update)
  }

  go() {
    window.scrollTo({ top: 0, behavior: "instant" })
    focusPageStart()
    this.update()
  }

  // The heading is looked up each time: a refresh in place can replace it.
  pastHeading() {
    const heading = document.querySelector("main h1")
    if (!heading) return window.scrollY > WITHOUT_HEADING

    const header = this.element.closest("header")
    const covered = header ? header.getBoundingClientRect().bottom : 0
    return heading.getBoundingClientRect().bottom <= covered
  }
}
