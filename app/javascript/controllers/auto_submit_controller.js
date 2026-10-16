import { Controller } from "@hotwired/stimulus"

// A form whose only control is a checkbox saves as soon as it changes
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
