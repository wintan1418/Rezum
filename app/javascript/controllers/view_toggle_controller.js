import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view", "button"]
  static values = { current: { type: String, default: "side-by-side" } }

  switch(event) {
    const mode = event.currentTarget.dataset.mode
    this.currentValue = mode

    this.viewTargets.forEach(v => {
      v.classList.toggle("hidden", v.dataset.mode !== mode)
    })

    this.buttonTargets.forEach(b => {
      const active = b.dataset.mode === mode
      b.classList.toggle("bg-blue-600", active)
      b.classList.toggle("text-white", active)
      b.classList.toggle("bg-white", !active)
      b.classList.toggle("text-gray-700", !active)
    })
  }
}
