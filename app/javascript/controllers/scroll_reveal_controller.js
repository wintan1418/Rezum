import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("opacity-100", "translate-y-0")
          entry.target.classList.remove("opacity-0", "translate-y-8")
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.1, rootMargin: "0px 0px -40px 0px" })

    this.itemTargets.forEach((item) => {
      item.classList.add("opacity-0", "translate-y-8", "transition-all", "duration-700", "ease-out")
      this.observer.observe(item)
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
