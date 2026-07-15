import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "feedback"]

  copy(event) {
    const text = event.currentTarget.dataset.clipboardText ||
      (this.hasSourceTarget ? (this.sourceTarget.value || this.sourceTarget.textContent) : "")
    if (!text) return

    navigator.clipboard.writeText(text)
    if (!this.hasFeedbackTarget) return

    if (this.resetTimeout) {
      clearTimeout(this.resetTimeout)
    } else {
      this.originalFeedback = this.feedbackTarget.textContent
    }
    this.feedbackTarget.textContent = "Copied!"
    this.feedbackTarget.classList.add("text-green-600")
    this.resetTimeout = setTimeout(() => {
      this.feedbackTarget.textContent = this.originalFeedback
      this.feedbackTarget.classList.remove("text-green-600")
      this.resetTimeout = null
    }, 2000)
  }
}
