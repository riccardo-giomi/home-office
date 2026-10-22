import { Controller } from "@hotwired/stimulus"

// Keeps the keyboard focus on the control the user just used after the page
// refreshes. If that control is gone, focus goes to the page heading.
//
// A refresh can remove or move the focused element, and the browser then puts
// focus on <body>: a keyboard user would start again from the top of the page.
// Turbo also disables a submit button while its request runs, which drops focus
// too, so the control is noted when its form is submitted.
export default class extends Controller {
  connect() {
    this.check = () => requestAnimationFrame(() => this.restore())
    // Note the control used (the submitter, else the focused element) before
    // Turbo disables it.
    this.remember = (event) =>
      (this.focusedId = event.submitter?.id || document.activeElement?.id || null)
    document.addEventListener("submit", this.remember, true)
    document.addEventListener("turbo:morph", this.check)
    document.addEventListener("turbo:render", this.check)
    // `close` does not bubble: listen while it travels down.
    document.addEventListener("close", this.check, true)
  }

  disconnect() {
    document.removeEventListener("submit", this.remember, true)
    document.removeEventListener("turbo:morph", this.check)
    document.removeEventListener("turbo:render", this.check)
    document.removeEventListener("close", this.check, true)
  }

  restore() {
    const active = document.activeElement
    const lost =
      !active || active === document.body || active.closest("dialog:not([open])")
    // The noted control is for this refresh only.
    const remembered = this.focusedId
    this.focusedId = null
    if (!lost) return

    const same = remembered && document.getElementById(remembered)
    if (same) return same.focus({ preventScroll: true })

    const heading = document.querySelector("main h1")
    if (!heading) return
    if (!heading.hasAttribute("tabindex")) heading.setAttribute("tabindex", "-1")
    heading.classList.add("focus:outline-none")
    // Do not scroll: the morph already kept the scroll position.
    heading.focus({ preventScroll: true })
  }
}
