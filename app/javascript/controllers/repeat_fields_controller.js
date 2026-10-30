import { Controller } from "@hotwired/stimulus"

// The Repeat fields of the event form.
//
// It shows only the fields that the chosen frequency and end use. Without this
// controller every field shows, and the server ignores the ones that do not
// apply.
//
// It also reads the rule back in words, in a polite live region. The words come
// from the server, the one place that knows them: the same text the lists show.
export default class extends Controller {
  static targets = ["frequency", "part", "end", "summary"]
  static values = { url: String }

  connect() {
    this.form = this.element.closest("form")
    this.listener = (event) => { if (this.concerns(event.target)) this.update(event) }
    this.form.addEventListener("input", this.listener)
    this.form.addEventListener("change", this.listener)
    this.showFields()
  }

  disconnect() {
    this.form.removeEventListener("input", this.listener)
    this.form.removeEventListener("change", this.listener)
    clearTimeout(this.timer)
  }

  // The repeat fields and the day (the day-based parts of the rule follow it).
  concerns(field) {
    return field.name?.startsWith("repeat[") || field.name?.endsWith("[day]")
  }

  update(event) {
    this.followDay(event?.target)
    this.showFields()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refreshSummary(), 250)
  }

  // Until the user ticks a weekday, the one ticked is the weekday of the day
  // they chose.
  followDay(field) {
    if (field?.name === "repeat[weekdays][]") return void (this.weekdaysChosen = true)
    if (this.weekdaysChosen || !field?.name?.endsWith("[day]") || !field.value) return

    const code = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][new Date(`${field.value}T12:00:00`).getDay()]
    this.element.querySelectorAll("input[name='repeat[weekdays][]']").forEach((box) => { box.checked = box.value === code })
  }

  showFields() {
    const frequency = this.frequencyTarget.value
    const ends = this.element.querySelector("input[name='repeat[ends]']:checked")?.value
    this.partTargets.forEach((part) => { part.hidden = !part.dataset.frequencies.split(" ").includes(frequency) })
    this.endTargets.forEach((end) => { end.hidden = end.dataset.ends !== ends })
  }

  async refreshSummary() {
    const turn = (this.turn = (this.turn || 0) + 1)
    const params = new URLSearchParams()
    for (const [name, value] of new FormData(this.form)) {
      if (name.startsWith("repeat[")) params.append(name, value)
    }
    params.set("day", this.form.querySelector("[name$='[day]']")?.value || "")
    try {
      const response = await fetch(`${this.urlValue}?${params}`, { headers: { Accept: "text/plain" } })
      // A slower answer to an older question must not replace the newer one.
      if (response.ok && turn === this.turn) this.summaryTarget.textContent = await response.text()
    } catch {
      // The words are a help, not the form: offline or failing, the form still
      // saves.
    }
  }
}
