import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Lets the user reorder a list by dragging a row by its handle.
//
// A drop is sent to the server as "this row now follows that row" (or "precedes
// that row", at the top) through the list's hidden form, so Turbo handles the
// answer like any other form submission. Dragging is a shortcut: the move
// buttons do the same.
export default class extends Controller {
  static targets = ["list", "form", "after", "before"]
  static values = { handle: String }

  connect() {
    const reduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches
    this.sortable = Sortable.create(this.listTarget, {
      handle: this.handleValue,
      draggable: "li",
      animation: reduced ? 0 : 150,
      onEnd: (event) => this.drop(event)
    })
  }

  disconnect() {
    // Turbo may restore the page from its cache: destroy the instance so the
    // list is not made sortable twice.
    this.sortable?.destroy()
    this.sortable = null
  }

  drop({ item, oldIndex, newIndex }) {
    if (oldIndex === newIndex) return

    const previous = item.previousElementSibling
    const next = item.nextElementSibling
    this.afterTarget.value = previous ? previous.dataset.sortableItemId : ""
    this.beforeTarget.value = previous ? "" : next.dataset.sortableItemId
    this.formTarget.action = item.dataset.sortableUrl
    this.formTarget.requestSubmit()
  }
}
