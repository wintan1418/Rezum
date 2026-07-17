import { Controller } from "@hotwired/stimulus"

// Cursor-following radial highlight on cards (the Linear/Vercel effect).
// Mount once on a page wrapper; any element matching SELECTOR gets a
// spotlight driven by --mx/--my custom properties. Pure delegation, one
// listener, rAF-throttled.
const SELECTOR = ".steps > *, .pricing > *, .vs-grid > *, .tour-row"

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (window.matchMedia("(hover: none)").matches) return

    this.element.querySelectorAll(SELECTOR).forEach((el) => el.classList.add("spot-card"))

    this.onMove = (event) => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        const card = event.target.closest?.(".spot-card")
        if (!card) return
        const rect = card.getBoundingClientRect()
        card.style.setProperty("--mx", `${event.clientX - rect.left}px`)
        card.style.setProperty("--my", `${event.clientY - rect.top}px`)
      })
    }
    this.element.addEventListener("mousemove", this.onMove, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("mousemove", this.onMove)
    cancelAnimationFrame(this.frame)
  }
}
