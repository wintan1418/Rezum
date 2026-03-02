import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "radio"]

  select(event) {
    const selected = event.target.value

    this.labelTargets.forEach(label => {
      const card = label.querySelector('.template-card')
      const check = label.querySelector('.template-check')
      const isSelected = label.dataset.template === selected

      if (isSelected) {
        card.classList.remove('border-gray-200', 'hover:border-gray-300')
        card.classList.add('border-blue-600', 'bg-blue-50')
        check.classList.remove('hidden')
        check.classList.add('flex')
      } else {
        card.classList.remove('border-blue-600', 'bg-blue-50')
        card.classList.add('border-gray-200', 'hover:border-gray-300')
        check.classList.remove('flex')
        check.classList.add('hidden')
      }
    })
  }
}
