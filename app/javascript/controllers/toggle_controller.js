import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "trigger"]
  static values = { showText: String, hideText: String }

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180")
    }
    if (this.hasTriggerTarget && this.hasShowTextValue) {
      const hidden = this.contentTarget.classList.contains("hidden")
      this.triggerTarget.textContent = hidden ? this.showTextValue : this.hideTextValue
    }
  }
}
