import { Controller } from "@hotwired/stimulus"

// Scrolls its element into view when it connects, for content that appears
// below the visible part of the page: a dialog that just opened, or the record
// named by a link.
//
// `block` is where the element ends up in the scrolling area: "start" (the
// default) or "center".
export default class extends Controller {
  static values = { block: { type: String, default: "start" } }

  connect() {
    this.element.scrollIntoView({ block: this.blockValue })
  }
}
