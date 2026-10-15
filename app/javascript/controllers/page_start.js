// Where a page starts for focus: its heading, else the main area. A heading is not a control, so it gets
// a tabindex for the script and no ring (browsers draw one on script focus after keyboard use).
export function focusPageStart() {
  const target = document.querySelector("main h1") || document.querySelector("main")
  if (!target.hasAttribute("tabindex")) target.setAttribute("tabindex", "-1")
  target.classList.add("focus:outline-none")
  target.focus()
}
