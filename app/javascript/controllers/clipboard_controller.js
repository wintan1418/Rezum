import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "feedback"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value || this.sourceTarget.textContent)
    const original = this.feedbackTarget.textContent
    this.feedbackTarget.textContent = "Copied!"
    this.feedbackTarget.classList.add("text-green-600")
    setTimeout(() => {
      this.feedbackTarget.textContent = original
      this.feedbackTarget.classList.remove("text-green-600")
    }, 2000)
  }
}
