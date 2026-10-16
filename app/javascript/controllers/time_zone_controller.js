import { Controller } from "@hotwired/stimulus"

// Tells the server the browser's IANA time zone through a cookie (no request body needed)
export default class extends Controller {
  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!zone || this.currentCookie() === zone) return

    document.cookie = `time_zone=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`
  }

  currentCookie() {
    const match = document.cookie.match(/(?:^|; )time_zone=([^;]*)/)
    return match ? decodeURIComponent(match[1]) : null
  }
}
