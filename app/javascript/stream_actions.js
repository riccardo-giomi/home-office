import { Turbo } from "@hotwired/turbo-rails"

// <turbo-stream action="close_dialog" target="dialog-id">: the server closes a
// dialog once a change has been made in it.
Turbo.StreamActions.close_dialog = function () {
  this.targetElements.forEach((dialog) => {
    if (dialog.open) dialog.close()
  })
}

// <turbo-stream action="focus" target="element-id">: the server hands focus to
// an element once a change is done.
//
// The page refresh that comes with such a change moves the dialog (a permanent
// element) about, and the browser drops focus to the body or to the link that
// opened the dialog. So for the next three seconds focus is given back after
// each render, but only when it has left the group the target belongs to.
Turbo.StreamActions.focus = function () {
  const id = this.getAttribute("target")
  const focus = () => document.getElementById(id)?.focus()
  focus()

  const lost = () =>
    !document
      .getElementById(id)
      ?.closest("[role=group]")
      ?.contains(document.activeElement)
  const again = () =>
    requestAnimationFrame(() => {
      if (lost()) focus()
    })
  document.addEventListener("turbo:render", again)
  setTimeout(() => document.removeEventListener("turbo:render", again), 3000)
}
