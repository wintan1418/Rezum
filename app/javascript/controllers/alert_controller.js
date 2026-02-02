import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = { timeout: { type: Number, default: 7000 } }

  connect() {
    // Add slide-in animation
    this.element.classList.add('animate-slide-in')
    
    // Auto dismiss after timeout
    if (this.timeoutValue > 0) {
      this.timeoutId = setTimeout(() => this.dismiss(), this.timeoutValue)
    }
  }

  disconnect() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  dismiss(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    // Slide out animation
    this.element.classList.remove('animate-slide-in')
    this.element.classList.add('animate-slide-out')
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
