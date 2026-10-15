import { Controller } from "@hotwired/stimulus"

// Turbo scrolls to a same-page anchor but leaves focus on the link, so keyboard and
// screen reader users would not land in the field the link names. Focus it ourselves.
export default class extends Controller {
  focus(event) {
    const target = document.getElementById(event.currentTarget.hash.slice(1))
    if (!target) return

    event.preventDefault()
    target.focus()
  }
}
