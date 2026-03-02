import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  toggle(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const content = this.contentTargets[index]
    const icon = this.iconTargets[index]

    // Close all others
    this.contentTargets.forEach((el, i) => {
      if (i !== index) {
        el.style.maxHeight = null
        el.classList.add("hidden")
        this.iconTargets[i]?.classList.remove("rotate-180")
      }
    })

    // Toggle current
    if (content.classList.contains("hidden")) {
      content.classList.remove("hidden")
      content.style.maxHeight = content.scrollHeight + "px"
      icon?.classList.add("rotate-180")
    } else {
      content.style.maxHeight = null
      content.classList.add("hidden")
      icon?.classList.remove("rotate-180")
    }
  }
}
