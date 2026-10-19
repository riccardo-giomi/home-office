import { Controller } from "@hotwired/stimulus"

// A list that includes today opens on the start of today's container.
export default class extends Controller {
  connect() {
    requestAnimationFrame(() =>
      this.element
        .querySelector("[data-today]")
        ?.scrollIntoView({ block: "start" })
    )
  }
}
