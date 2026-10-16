import { Controller } from "@hotwired/stimulus"

// Turbo leaves <html> attributes alone, and a cached page would bring back the theme it was cached
// with. The theme cookie always holds the current choice (the server mirrors the stored one into it),
// so it is the source of truth in the browser; no cookie means automatic.
export default class extends Controller {
  connect() {
    const choice = document.cookie.match(/(?:^|; )theme=(light|dark)(?:;|$)/)?.[1]
    if (choice) document.documentElement.dataset.theme = choice
    else delete document.documentElement.dataset.theme
  }
}
