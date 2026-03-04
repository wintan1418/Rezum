import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "ngnBtn", "usdBtn"]

  showNGN() {
    this.amountTargets.forEach(el => {
      el.textContent = el.dataset.ngn
    })
    this.ngnBtnTarget.classList.add("bg-blue-600", "text-white")
    this.ngnBtnTarget.classList.remove("text-gray-500")
    this.usdBtnTarget.classList.remove("bg-blue-600", "text-white")
    this.usdBtnTarget.classList.add("text-gray-500")
  }

  showUSD() {
    this.amountTargets.forEach(el => {
      el.textContent = el.dataset.usd
    })
    this.usdBtnTarget.classList.add("bg-blue-600", "text-white")
    this.usdBtnTarget.classList.remove("text-gray-500")
    this.ngnBtnTarget.classList.remove("bg-blue-600", "text-white")
    this.ngnBtnTarget.classList.add("text-gray-500")
  }
}
