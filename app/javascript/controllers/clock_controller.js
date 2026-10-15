import { Controller } from "@hotwired/stimulus"

// Keeps the header clock current, in the user's own zone and formats (the server drew the first paint).
// Updates on the minute and again when the tab comes back from the background.
export default class extends Controller {
  static targets = ["date", "time"]
  static values = { zone: String, dateFormat: String, timeFormat: String, locale: String }

  connect() {
    this.onVisible = () => { if (!document.hidden) this.tick() }
    document.addEventListener("visibilitychange", this.onVisible)
    this.tick()
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("visibilitychange", this.onVisible)
  }

  tick() {
    clearTimeout(this.timer)
    this.update()
    this.timer = setTimeout(() => this.tick(), 60000 - (Date.now() % 60000) + 50)
  }

  update() {
    const p = Object.fromEntries(new Intl.DateTimeFormat(this.localeValue, {
      timeZone: this.zoneValue, weekday: "short", year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", minute: "2-digit", hourCycle: "h23"
    }).formatToParts(new Date(Date.now())).map((part) => [part.type, part.value]))

    const date = { dmy: `${p.day}/${p.month}/${p.year}`, mdy: `${p.month}/${p.day}/${p.year}`, ymd: `${p.year}-${p.month}-${p.day}` }[this.dateFormatValue]
    const hour = Number(p.hour)
    const time = this.timeFormatValue === "12h" ? `${hour % 12 || 12}:${p.minute} ${hour < 12 ? "AM" : "PM"}` : `${p.hour}:${p.minute}`

    this.dateTarget.textContent = `${p.weekday} ${date}`
    this.timeTarget.textContent = time
    this.element.setAttribute("datetime", `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`)
  }
}
