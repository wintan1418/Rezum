import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, interval: Number }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    if (this.pollingTimer) return

    this.pollingTimer = setInterval(() => {
      this.checkStatus()
    }, this.intervalValue || 3000)
  }

  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) return

      const html = await response.text()

      // If the response no longer contains our auto-refresh controller,
      // processing is done — reload the page properly via Turbo
      if (!html.includes('data-controller="auto-refresh"')) {
        this.stopPolling()
        window.Turbo.visit(window.location.href, { action: "replace" })
      }
    } catch (error) {
      // Continue polling on error
    }
  }
}
