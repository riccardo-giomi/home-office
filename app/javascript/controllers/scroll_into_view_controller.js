import { Controller } from "@hotwired/stimulus"

// Brings its element to the start of whatever scrolls around it, so that what
// has just opened below the fold, in a dialog for one, is not missed.
export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ block: "start" })
  }
}
