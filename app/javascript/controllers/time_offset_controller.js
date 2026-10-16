import { Controller } from "@hotwired/stimulus"

// Keeps a "to" time a fixed number of minutes after a "from" time until the person types their own
export default class extends Controller {
  static targets = ["source", "target"]
  static values = { minutes: { type: Number, default: 30 } }

  connect() {
    this.edited = this.targetTarget.value !== ""
  }

  markEdited() {
    this.edited = true
  }

  fill() {
    if (this.edited) return

    const [hours, minutes] = this.sourceTarget.value.split(":").map(Number)
    const total = hours * 60 + minutes + this.minutesValue
    if (Number.isNaN(total)) return void (this.targetTarget.value = "")

    // The suggestion stops at the end of the day; from 23:59 there is nothing left to suggest
    const last = 24 * 60 - 1
    this.targetTarget.value = hours * 60 + minutes >= last ? "" : this.clock(Math.min(total, last))
  }

  clock(total) {
    const pad = (number) => String(number).padStart(2, "0")
    return `${pad(Math.floor(total / 60))}:${pad(total % 60)}`
  }
}
