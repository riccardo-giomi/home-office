import { Controller } from "@hotwired/stimulus"

// Below the xl breakpoint (1280 px) the navigation is a panel the menu button opens
export default class extends Controller {
  // "page" is everything behind the panel (the header and the main content)
  static targets = ["panel", "backdrop", "button", "page"]

  connect() {
    this.wide = matchMedia("(min-width: 80rem)")
    this.onResize = () => { if (this.wide.matches) this.hide() }
    this.wide.addEventListener("change", this.onResize)
  }

  disconnect() {
    this.wide.removeEventListener("change", this.onResize)
  }

  get isOpen() {
    return this.panelTarget.hasAttribute("data-open")
  }

  open() {
    this.panelTarget.setAttribute("data-open", "")
    this.backdropTarget.setAttribute("data-open", "")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.pageTargets.forEach((element) => { element.inert = true })
    this.panelTarget.querySelector("a, button").focus()
  }

  // The user closed it (Escape, backdrop, close button): focus goes back to the menu button
  close() {
    if (!this.isOpen) return

    this.hide()
    this.buttonTarget.focus()
  }

  // Closed by the page itself (resize, Turbo cache snapshot): leave focus alone
  hide() {
    this.panelTarget.removeAttribute("data-open")
    this.backdropTarget.removeAttribute("data-open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.pageTargets.forEach((element) => { element.inert = false })
  }
}
