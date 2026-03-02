import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.handleScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  handleScroll() {
    if (window.scrollY > 20) {
      this.element.classList.add("bg-white/95", "backdrop-blur-md", "shadow-sm", "border-b", "border-gray-200")
      this.element.classList.remove("bg-transparent")
    } else {
      this.element.classList.remove("bg-white/95", "backdrop-blur-md", "shadow-sm", "border-b", "border-gray-200")
      this.element.classList.add("bg-transparent")
    }
  }
}
