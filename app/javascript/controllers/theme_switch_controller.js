import { Controller } from "@hotwired/stimulus"

// Applies the theme at once and saves it in the background; the server renders it on full loads
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.media = matchMedia("(prefers-color-scheme: dark)")
    this.sync = () => this.element.setAttribute("aria-checked", String(this.dark))
    this.media.addEventListener("change", this.sync)
    this.sync()
  }

  disconnect() {
    this.media.removeEventListener("change", this.sync)
  }

  get dark() {
    return getComputedStyle(document.documentElement).colorScheme === "dark"
  }

  async toggle() {
    const theme = this.dark ? "light" : "dark"
    document.documentElement.dataset.theme = theme
    this.sync()
    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content ?? "",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({ theme })
    })
  }
}
