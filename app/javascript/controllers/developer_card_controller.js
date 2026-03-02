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
}
