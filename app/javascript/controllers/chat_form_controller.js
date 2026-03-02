import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.element.addEventListener("turbo:submit-end", () => {
      if (this.hasInputTarget) {
        this.inputTarget.value = ""
        this.inputTarget.focus()
      }
    })
  }
}
