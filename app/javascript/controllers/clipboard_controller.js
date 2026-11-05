import { Controller } from "@hotwired/stimulus"

// Copies the text of a field and shows the result.
//
// Without the clipboard (an old browser, a page not served over https) the
// button stays hidden, and the field can still be selected by hand.
export default class extends Controller {
  static targets = ["source", "button", "status"]
  static values = { done: String, failed: String }

  connect() {
    if (navigator.clipboard) this.buttonTarget.hidden = false
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.statusTarget.textContent = this.doneValue
    } catch {
      this.sourceTarget.select()
      this.statusTarget.textContent = this.failedValue
    }
  }
}
