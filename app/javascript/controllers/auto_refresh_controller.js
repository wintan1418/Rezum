import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, interval: Number }

  connect() {
    // Start polling when the controller connects
    this.startPolling()
  }

  disconnect() {
    // Clean up when the controller disconnects
    this.stopPolling()
  }

  startPolling() {
    // Don't start if already polling
    if (this.pollingTimer) return

    console.log("Starting auto-refresh polling...", this.urlValue)
    
    this.pollingTimer = setInterval(() => {
      this.refreshContent()
    }, this.intervalValue || 3000) // Default 3 seconds
  }

  stopPolling() {
    if (this.pollingTimer) {
      console.log("Stopping auto-refresh polling...")
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
    }
  }

  async refreshContent() {
    try {
      console.log("Fetching updated content from:", this.urlValue)
      
      const response = await fetch(this.urlValue, {
        method: "GET",
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const html = await response.text()
      
      // Create a temporary element to parse the response
      const tempDiv = document.createElement('div')
      tempDiv.innerHTML = html
      
      // Find the main content area in the response
      const newContent = tempDiv.querySelector('main')
      const currentContent = document.querySelector('main')
      
      if (newContent && currentContent) {
        // Replace the entire main content
        currentContent.innerHTML = newContent.innerHTML
        console.log("Content updated successfully")
        
        // Check if we should stop polling (no more generating state)
        const stillGenerating = newContent.querySelector('[data-controller*="auto-refresh"]')
        if (!stillGenerating) {
          console.log("Generation complete, stopping polling")
          this.stopPolling()
        }
      }
    } catch (error) {
      console.error("Error refreshing content:", error)
      // Continue polling even if there's an error
    }
  }
}