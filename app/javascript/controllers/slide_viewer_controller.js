import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Scroll to specific slide if URL has ?slide=type
    const params = new URLSearchParams(window.location.search)
    const slideType = params.get("slide")
    if (slideType) {
      const el = document.getElementById(`slide_${slideType}`)
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "center" })
        el.classList.add("ring-2", "ring-purple-400")
        setTimeout(() => el.classList.remove("ring-2", "ring-purple-400"), 2000)
      }
    }
  }
}
