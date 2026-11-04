import { Controller } from "@hotwired/stimulus"

// Refreshes the page when it comes back after being away.
//
// The refresh is a Turbo visit to the same address with action `replace`. The
// page morphs, so the scroll position and the focus are kept.
//
// It is away when it is out of view, in another tab or in a minimized window.
// When it becomes visible again it is refreshed if it was rendered at least
// `seconds` ago, so switching back and forth quickly does nothing. It does
// nothing when it becomes hidden.
export default class extends Controller {
  static values = { seconds: { type: Number, default: 60 } }

  connect() {
    this.renderedAt = Date.now()
    this.onVisibility = () => this.refreshIfOld()
    this.onRender = () => {
      this.renderedAt = Date.now()
    }
    document.addEventListener("visibilitychange", this.onVisibility)
    document.addEventListener("turbo:render", this.onRender)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    document.removeEventListener("turbo:render", this.onRender)
  }

  refreshIfOld() {
    if (document.visibilityState !== "visible") return
    if (Date.now() - this.renderedAt < this.secondsValue * 1000) return

    this.refresh()
  }

  refresh() {
    this.renderedAt = Date.now()
    Turbo.visit(location.href, { action: "replace" })
  }
}
