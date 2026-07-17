import { Controller } from "@hotwired/stimulus"

// Animates numbers up when they scroll into view.
// Usage: <span data-controller="count-up" data-count-up-to-value="47"
//              data-count-up-prefix-value="+" data-count-up-suffix-value="%"></span>
export default class extends Controller {
  static values = {
    to: Number,
    prefix: { type: String, default: "" },
    suffix: { type: String, default: "" },
    duration: { type: Number, default: 1400 }
  }

  connect() {
    this.render(this.toValue) // final state as fallback

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        this.observer.disconnect()
        this.animate()
      })
    }, { threshold: 0.6 })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
    cancelAnimationFrame(this.frame)
  }

  animate() {
    const start = performance.now()
    const step = (now) => {
      const progress = Math.min((now - start) / this.durationValue, 1)
      // easeOutQuint — matches the reveal curve
      const eased = 1 - Math.pow(1 - progress, 5)
      this.render(Math.round(this.toValue * eased))
      if (progress < 1) this.frame = requestAnimationFrame(step)
    }
    this.frame = requestAnimationFrame(step)
  }

  render(value) {
    this.element.textContent = `${this.prefixValue}${value}${this.suffixValue}`
  }
}
