import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "badge"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }
}
