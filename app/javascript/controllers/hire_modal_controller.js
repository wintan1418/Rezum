import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  open(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.modalTarget.querySelector("[data-card]").classList.remove("scale-95", "opacity-0")
      this.modalTarget.querySelector("[data-card]").classList.add("scale-100", "opacity-100")
    })
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event) event.preventDefault()
    const card = this.modalTarget.querySelector("[data-card]")
    card.classList.remove("scale-100", "opacity-100")
    card.classList.add("scale-95", "opacity-0")
    setTimeout(() => {
      this.modalTarget.classList.add("hidden")
      document.body.style.overflow = ""
    }, 200)
  }

  backdropClose(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  submitStart() {
    const btn = this.element.querySelector("[data-submit-btn]")
    if (btn) {
      btn.disabled = true
      btn.innerHTML = '<svg class="animate-spin w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg> Sending...'
    }
  }
}
