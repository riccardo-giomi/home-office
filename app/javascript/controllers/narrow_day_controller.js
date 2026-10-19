import { Controller } from "@hotwired/stimulus"

// Switches to a different page when the width becomes less than 640 px (a
// phone).
//
// JavaScript is required anyway, so this moves the visitor over.
export default class extends Controller {
  static values = { href: String }

  connect() {
    this.narrow = matchMedia("(width < 40rem)")
    this.onChange = () => this.check()
    this.narrow.addEventListener("change", this.onChange)
    this.check()
  }

  disconnect() {
    this.narrow.removeEventListener("change", this.onChange)
  }

  check() {
    if (this.narrow.matches) Turbo.visit(this.hrefValue, { action: "replace" })
  }
}
