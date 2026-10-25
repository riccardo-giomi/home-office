import NowMarker from "controllers/now_marker_controller"

// The current time in a grid that draws only some hours of the day.
//
// The minute is mapped to its place among the visible stretches, and the line
// is hidden while the clock is in a hidden one. `segments` holds
// [from, to, offset] in minutes: where a stretch is in the day and where it
// starts among the visible minutes.
export default class extends NowMarker {
  static values = {
    minutes: Number,
    renderedAt: Number,
    segments: Array,
    total: Number,
  }

  move(minutes) {
    const stretch = this.segmentsValue.find(
      ([from, to]) => minutes >= from && minutes < to,
    )
    this.element.hidden = !stretch
    if (!stretch) return

    const [from, , offset] = stretch
    this.element.style.top = `${((offset + minutes - from) / this.totalValue) * 100}%`
  }
}
