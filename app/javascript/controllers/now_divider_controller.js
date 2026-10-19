import NowMarker from "controllers/now_marker_controller"

// The current time in a list of entries of one day: a divider between the
// entries that have started and those still to come.
//
// Entries carry `data-start-minutes`; all-day ones have none and stay above
// it.
export default class extends NowMarker {
  static values = { minutes: Number, renderedAt: Number }

  move(minutes) {
    const timed = [
      ...this.element.parentElement.querySelectorAll(
        ":scope > [data-start-minutes]"
      )
    ]
    const next = timed.find(
      (entry) => Number(entry.dataset.startMinutes) > minutes
    )
    if (next) {
      if (this.element.nextElementSibling !== next) next.before(this.element)
    } else if (this.element.parentElement.lastElementChild !== this.element) {
      this.element.parentElement.append(this.element)
    }
  }
}
