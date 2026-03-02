import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["column", "card"]

  connect() {
    this.cardTargets.forEach(card => {
      card.setAttribute("draggable", "true")
    })
  }

  dragstart(event) {
    event.dataTransfer.setData("application/job-id", event.currentTarget.dataset.jobId)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("opacity-50", "rotate-1")
  }

  dragend(event) {
    event.currentTarget.classList.remove("opacity-50", "rotate-1")
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    const column = event.currentTarget
    column.classList.add("bg-blue-50/50", "ring-2", "ring-blue-300", "ring-inset")
  }

  dragleave(event) {
    const column = event.currentTarget
    column.classList.remove("bg-blue-50/50", "ring-2", "ring-blue-300", "ring-inset")
  }

  drop(event) {
    event.preventDefault()
    const column = event.currentTarget
    column.classList.remove("bg-blue-50/50", "ring-2", "ring-blue-300", "ring-inset")

    const jobId = event.dataTransfer.getData("application/job-id")
    const newStatus = column.dataset.status
    const card = document.querySelector(`[data-job-id="${jobId}"]`)

    if (!card || !newStatus) return

    // Move card visually
    const cardList = column.querySelector("[data-kanban-target='cardList']")
    if (cardList) {
      cardList.appendChild(card)
    }

    // Update count badges
    this.updateColumnCounts()

    // Persist to server
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/job_applications/${jobId}/move`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ status: newStatus })
    }).then(response => {
      if (!response.ok) {
        window.location.reload()
      }
    }).catch(() => {
      window.location.reload()
    })
  }

  updateColumnCounts() {
    this.columnTargets.forEach(column => {
      const cardList = column.querySelector("[data-kanban-target='cardList']")
      const countBadge = column.querySelector("[data-kanban-target='count']")
      if (cardList && countBadge) {
        countBadge.textContent = cardList.children.length
      }
    })
  }
}
