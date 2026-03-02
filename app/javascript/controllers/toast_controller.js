import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    // Slide in animation
    this.element.style.transform = "translateX(100%)"
    this.element.style.opacity = "0"
    requestAnimationFrame(() => {
      this.element.style.transition = "all 0.3s ease-out"
      this.element.style.transform = "translateX(0)"
      this.element.style.opacity = "1"
    })

    // Auto dismiss
    if (this.durationValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "all 0.3s ease-in"
    this.element.style.transform = "translateX(100%)"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
