import { Controller } from "@hotwired/stimulus"

// Keeps the line above a date field in step with the field.
//
// A date input holds its value as yyyy-mm-dd, whatever the browser shows. The
// line shows the weekday and the date in the user's own format (`pattern`, a
// strftime pattern with %d, %m and %Y), so the user can tell which day the
// browser understood from what was typed.
//
// The value is split as text, not read as a Date: a Date would shift the day
// with the time zone of the browser.
export default class extends Controller {
  static targets = ["input", "text"]
  static values = { pattern: String, dayNames: Array }

  update() {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(this.inputTarget.value)
    this.textTarget.textContent = match ? `${this.weekday(match)} ${this.format(match)}` : ""
  }

  format([, year, month, day]) {
    return this.patternValue.replace("%Y", year).replace("%m", month).replace("%d", day)
  }

  weekday([, year, month, day]) {
    const weekday = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day))).getUTCDay()
    return this.dayNamesValue[weekday]
  }
}
