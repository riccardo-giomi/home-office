import { Controller } from "@hotwired/stimulus"

// The current time, drawn in a view.
//
// The server says which minute of the day it was when the page was drawn; the
// script follows real time from there (no clock of the browser's own zone is
// needed, so the user's chosen time zone is respected).
//
// Subclasses decide how a minute shows (`move`): a line in a day column, a
// divider in a list.
//
// Past midnight the day is no longer today: reload the page.
export default class extends Controller {
  static values = { minutes: Number, renderedAt: Number }

  connect() {
    this.place()
    this.timer = setInterval(() => this.place(), 15000)
    this.onVisible = () => {
      if (!document.hidden) this.place()
    }
    document.addEventListener("visibilitychange", this.onVisible)
    // A refresh in place (morph) gives the element back the server's state,
    // and does not connect it again
    this.onRender = (event) => {
      if (event.detail?.renderMethod === "morph") this.draw()
    }
    document.addEventListener("turbo:render", this.onRender)
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("visibilitychange", this.onVisible)
    document.removeEventListener("turbo:render", this.onRender)
  }

  place() {
    if (this.minutesNow() >= 1440) {
      clearInterval(this.timer)
      Turbo.visit(location.href, { action: "replace" })
      return
    }
    this.draw()
  }

  // Also after a refresh in place, which gives the element the server's state
  // again (invisible, no position)
  draw() {
    this.move(this.minutesNow())
    this.element.classList.remove("invisible")
  }

  minutesNow() {
    return this.minutesValue + (Date.now() - this.renderedAtValue) / 60000
  }

  // A line at that height of the day column (the column is as tall as the day).
  //
  // The CSP disallows setting a position with `style` in the markup but allows
  // changing `element.style.top` from a script.
  move(minutes) {
    this.element.style.top = `${(minutes / 1440) * 100}%`
  }
}
