import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.itemTargets.forEach(item => {
      item.setAttribute("draggable", "true")
    })
  }

  dragstart(event) {
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.sectionId)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("opacity-50")
  }

  dragend(event) {
    event.currentTarget.classList.remove("opacity-50")
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  drop(event) {
    event.preventDefault()
    const draggedId = event.dataTransfer.getData("text/plain")
    const dropTarget = event.currentTarget
    const draggedElement = this.element.querySelector(`[data-section-id="${draggedId}"]`)

    if (!draggedElement || draggedElement === dropTarget) return

    const items = [...this.itemTargets]
    const draggedIndex = items.indexOf(draggedElement)
    const dropIndex = items.indexOf(dropTarget)

    if (draggedIndex < dropIndex) {
      dropTarget.parentNode.insertBefore(draggedElement, dropTarget.nextSibling)
    } else {
      dropTarget.parentNode.insertBefore(draggedElement, dropTarget)
    }

    // Save new order to server
    this.saveOrder()
  }

  saveOrder() {
    const order = this.itemTargets.map(item => item.dataset.sectionId)
    const resumeId = this.element.dataset.resumeId
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(`/resumes/${resumeId}/builder/reorder`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ order })
    })
  }
}
