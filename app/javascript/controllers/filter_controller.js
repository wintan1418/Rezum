import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "button", "count"]

  filter(event) {
    const status = event.currentTarget.dataset.status

    this.buttonTargets.forEach((btn) => {
      if (btn.dataset.status === status) {
        btn.classList.add("bg-blue-600", "text-white")
        btn.classList.remove("bg-white", "text-gray-700", "hover:bg-gray-50")
      } else {
        btn.classList.remove("bg-blue-600", "text-white")
        btn.classList.add("bg-white", "text-gray-700", "hover:bg-gray-50")
      }
    })

    let visible = 0
    this.cardTargets.forEach((card) => {
      if (status === "all" || card.dataset.status === status) {
        card.classList.remove("hidden")
        visible++
      } else {
        card.classList.add("hidden")
      }
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = visible
    }
  }
}
