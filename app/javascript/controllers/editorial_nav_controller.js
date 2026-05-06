import { Controller } from "@hotwired/stimulus"

// Editorial nav: stays sticky (always visible), gains a "scrolled" class
// after the user passes the hero so it can render with a subtle shadow
// and tighter spacing. Also drives the floating back-to-top arrow.
export default class extends Controller {
  static targets = ["topBtn"]
  static values = { threshold: { type: Number, default: 240 } }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const y = window.scrollY
    const past = y > this.thresholdValue

    // Toggle scrolled state on the nav element
    if (past) {
      this.element.classList.add("scrolled")
    } else {
      this.element.classList.remove("scrolled")
    }

    // Toggle visibility of the back-to-top button
    if (this.hasTopBtnTarget) {
      if (y > 600) {
        this.topBtnTarget.classList.add("show")
      } else {
        this.topBtnTarget.classList.remove("show")
      }
    }
  }

  scrollTop(event) {
    event?.preventDefault()
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
