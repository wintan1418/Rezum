import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["circle", "number"]

  connect() {
    // Animate after a short delay for visual effect
    setTimeout(() => this.animate(), 100)
  }

  animate() {
    // Animate the SVG circle
    if (this.hasCircleTarget) {
      const finalOffset = this.circleTarget.dataset.finalOffset
      this.circleTarget.style.strokeDashoffset = finalOffset
    }

    // Animate the score number counting up
    if (this.hasNumberTarget) {
      const finalScore = parseInt(this.numberTarget.dataset.finalScore) || 0
      this.countUp(0, finalScore, 1500)
    }
  }

  countUp(current, target, duration) {
    const start = performance.now()

    const step = (timestamp) => {
      const elapsed = timestamp - start
      const progress = Math.min(elapsed / duration, 1)

      // Ease out
      const eased = 1 - Math.pow(1 - progress, 3)
      const value = Math.round(eased * target)

      this.numberTarget.textContent = value

      if (progress < 1) {
        requestAnimationFrame(step)
      }
    }

    requestAnimationFrame(step)
  }
}
