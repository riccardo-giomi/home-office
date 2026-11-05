import { Controller } from "@hotwired/stimulus"

// Refreshes the page when it comes back after being away.
//
// The refresh is a Turbo visit to the same address with action `replace`. The
// page morphs, so the scroll position and the focus are kept.
//
// The page is away in two ways.
//
// It can be out of view, in another tab or in a
// minimized window. When it becomes visible again it is refreshed if it was
// rendered at least `seconds` ago, so switching back and forth quickly does
// nothing. It does nothing when it becomes hidden.
//
// Or the connection of its stream can drop. The messages sent meanwhile are
// lost, so when the connection is back the page is refreshed whatever its age.
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
    this.watchStream()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    document.removeEventListener("turbo:render", this.onRender)
    this.streamObserver.disconnect()
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

  // The stream element has the attribute `connected` while its subscription is
  // confirmed, and loses it when the connection drops. The first time it
  // appears is the page loading, not a return.
  watchStream() {
    this.dropped = false
    this.streamObserver = new MutationObserver((records) => {
      for (const { target } of records) {
        if (!target.hasAttribute("connected")) {
          this.dropped = true
        } else if (this.dropped) {
          this.dropped = false
          this.refresh()
        }
      }
    })
    this.streamObserver.observe(this.element, {
      subtree: true,
      attributes: true,
      attributeFilter: ["connected"]
    })
  }
}
