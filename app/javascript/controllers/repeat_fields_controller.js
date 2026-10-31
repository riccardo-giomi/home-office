import { Controller } from "@hotwired/stimulus"

// The Repeat fields of the event form.
//
// It shows only the fields that the chosen frequency and end use. Without this
// controller every field shows, and the server ignores the ones that do not
// apply.
//
// It also reads the rule back in words, in a polite live region. The words come
// from the server, the one place that knows them: the same text the lists show.
//
// On the form of an occurrence of a series it also follows the scope chosen
// ("Apply to"): the rule is for several events, so its fields are off for "This
// event", and the day is the event's own, so it is off for "All events".
export default class extends Controller {
  static targets = ["frequency", "part", "end", "summary"]
  static values = { url: String, followDay: Boolean }

  connect() {
    this.form = this.element.closest("form")
    this.listener = (event) => { if (this.concerns(event.target)) this.update(event) }
    this.form.addEventListener("input", this.listener)
    this.form.addEventListener("change", this.listener)
    this.showFields()
    this.followScope()
  }

  disconnect() {
    this.form.removeEventListener("input", this.listener)
    this.form.removeEventListener("change", this.listener)
    clearTimeout(this.timer)
  }

  // The repeat fields, the day (the day-based parts of the rule follow it) and
  // the scope.
  concerns(field) {
    return field.name?.startsWith("repeat[") || field.name?.endsWith("[day]") || field.name === "apply[scope]"
  }

  update(event) {
    this.followDay(event?.target)
    this.followScope()
    this.showFields()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refreshSummary(), 250)
  }

  // On the form of a new event, until the user ticks a weekday, the one ticked
  // is the weekday of the day they chose. The weekdays of an event that is
  // already part of a series are the ones of its rule, and stay.
  followDay(field) {
    if (!this.followDayValue) return
    if (field?.name === "repeat[weekdays][]") return void (this.weekdaysChosen = true)
    if (this.weekdaysChosen || !field?.name?.endsWith("[day]") || !field.value) return

    const code = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][new Date(`${field.value}T12:00:00`).getDay()]
    this.element.querySelectorAll("input[name='repeat[weekdays][]']").forEach((box) => { box.checked = box.value === code })
  }

  // The fields that the scope chosen cannot change are off: the rule for "This
  // event", the day for "All events". A form with no scope has them all on.
  followScope() {
    const scope = this.form.querySelector("input[name='apply[scope]']:checked")?.value
    this.ruleOff = scope === "this"
    if (!scope) return

    this.element.querySelectorAll("input, select").forEach((field) => { field.disabled = this.ruleOff })
    const day = this.form.querySelector("[name$='[day]']")
    if (day) day.disabled = scope === "all"
  }

  showFields() {
    const frequency = this.frequencyTarget.value
    const ends = this.element.querySelector("input[name='repeat[ends]']:checked")?.value
    this.partTargets.forEach((part) => { part.hidden = !part.dataset.frequencies.split(" ").includes(frequency) })
    this.endTargets.forEach((end) => { end.hidden = end.dataset.ends !== ends })
  }

  async refreshSummary() {
    // The fields are off, so there is nothing to read back.
    if (this.ruleOff) return

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
