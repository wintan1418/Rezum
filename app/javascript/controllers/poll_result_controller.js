import { Controller } from "@hotwired/stimulus"

// Polls a URL until it returns content (HTTP 200), then swaps itself out
// for the returned HTML. 204 means "not ready yet, keep polling".
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 2500 } }

  connect() {
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, { headers: { "Accept": "text/html" } })
      if (response.status !== 200) return

      const html = await response.text()
      if (!html.trim()) return

      clearInterval(this.timer)
      this.element.outerHTML = html
    } catch {
      // transient network error — keep polling
    }
  }
}
