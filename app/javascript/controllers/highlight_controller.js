import { Controller } from "@hotwired/stimulus"

// Shows for a moment that an element is the one that just changed: swaps a
// class pair, then swaps it back.
//
// The classes come from the page (so Tailwind sees them). Reduced motion needs
// no special case because the swap is instant, not an animation.
export default class extends Controller {
  static classes = ["on", "off"]
  static values = {
    duration: { type: Number, default: 2000 },
    token: String
  }

  connect() {
    this.connected = true
    this.start()
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timer)
  }

  // The page gives a new token each time it marks the element, so an element
  // that is still highlighted from an earlier change starts over.
  tokenValueChanged() {
    if (this.connected) this.start()
  }

  start() {
    clearTimeout(this.timer)
    this.element.classList.remove(...this.offClasses)
    this.element.classList.add(...this.onClasses)
    this.timer = setTimeout(() => this.clear(), this.durationValue)
  }

  clear() {
    this.element.classList.remove(...this.onClasses)
    this.element.classList.add(...this.offClasses)
    this.leave()
  }

  // Take this controller off the element when it is done. Otherwise the element
  // keeps the attribute, and when a later refresh marks it again the page sees
  // no change and the controller does not connect: there is no new highlight.
  leave() {
    const others = this.element
      .getAttribute("data-controller")
      .split(" ")
      .filter((name) => name !== this.identifier)
    if (others.length) this.element.setAttribute("data-controller", others.join(" "))
    else this.element.removeAttribute("data-controller")
  }
}
