import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "badge", "faqTab", "chatTab", "faqContent", "chatContent", "faqSearch", "faqItem", "faqIcon", "faqAnswer"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  showFaq() {
    this.faqContentTarget.classList.remove("hidden")
    this.chatContentTarget.classList.add("hidden")
    this.faqTabTarget.classList.add("border-blue-600", "text-blue-600")
    this.faqTabTarget.classList.remove("border-transparent", "text-gray-400")
    this.chatTabTarget.classList.add("border-transparent", "text-gray-400")
    this.chatTabTarget.classList.remove("border-blue-600", "text-blue-600")
  }

  showChat() {
    this.chatContentTarget.classList.remove("hidden")
    this.faqContentTarget.classList.add("hidden")
    this.chatTabTarget.classList.add("border-blue-600", "text-blue-600")
    this.chatTabTarget.classList.remove("border-transparent", "text-gray-400")
    this.faqTabTarget.classList.add("border-transparent", "text-gray-400")
    this.faqTabTarget.classList.remove("border-blue-600", "text-blue-600")
  }

  filterFaq() {
    const query = this.faqSearchTarget.value.toLowerCase().trim()
    this.faqItemTargets.forEach(item => {
      const questionText = item.dataset.question || ""
      item.style.display = (!query || questionText.includes(query)) ? "" : "none"
    })
  }

  toggleFaq(event) {
    const button = event.currentTarget
    const index = parseInt(button.dataset.index)
    const answer = this.faqAnswerTargets[index]
    const icon = this.faqIconTargets[index]

    if (answer) {
      answer.classList.toggle("hidden")
    }
    if (icon) {
      icon.classList.toggle("rotate-180")
    }
  }
}
