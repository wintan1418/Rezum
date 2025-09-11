import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Close dropdown when clicking outside
    this.boundClose = this.close.bind(this)
    document.addEventListener('click', this.boundClose)
  }

  disconnect() {
    document.removeEventListener('click', this.boundClose)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle('hidden')
  }

  close(event) {
    // Don't close if clicking inside the dropdown
    if (this.element.contains(event.target)) return
    
    this.menuTarget.classList.add('hidden')
  }
}