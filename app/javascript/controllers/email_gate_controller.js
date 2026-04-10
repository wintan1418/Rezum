import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gate", "content", "email"]

  unlock() {
    const email = this.emailTarget.value.trim()

    if (!email || !email.includes("@")) {
      this.emailTarget.classList.add("border-red-300", "ring-2", "ring-red-200")
      this.emailTarget.focus()
      setTimeout(() => {
        this.emailTarget.classList.remove("border-red-300", "ring-2", "ring-red-200")
      }, 2000)
      return
    }

    // Send email to backend
    fetch("/ats-checker/capture-email", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ email: email })
    }).catch(() => {}) // Fire and forget

    // Reveal content immediately
    if (this.hasGateTarget) this.gateTarget.classList.add("hidden")
    if (this.hasContentTarget) this.contentTarget.classList.remove("hidden")

    // Smooth scroll to revealed content
    if (this.hasContentTarget) {
      this.contentTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }
}
