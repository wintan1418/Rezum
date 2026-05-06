import { Controller } from "@hotwired/stimulus"

// Editorial nav controller
//
// 1. Sticky nav: adds .scrolled class after threshold for tighter look + shadow
// 2. Bidirectional floating arrow:
//    - At the top → arrow points DOWN, scrolls to first content section
//    - After scrolling → arrow points UP, scrolls back to top
// 3. Section reveal animations: lazy IntersectionObserver fades sections in
export default class extends Controller {
  static targets = ["topBtn", "topIcon", "downIcon"]
  static values = { threshold: { type: Number, default: 240 } }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
    this.observeSections()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    if (this.observer) this.observer.disconnect()
  }

  onScroll() {
    const y = window.scrollY
    const past = y > this.thresholdValue

    // Tighten nav once user passes the hero
    this.element.classList.toggle("scrolled", past)

    // Floating arrow: always visible. Direction flips by scroll position.
    if (this.hasTopBtnTarget) {
      this.topBtnTarget.classList.add("show")
      const isPastTop = y > 200
      this.topBtnTarget.classList.toggle("dir-up", isPastTop)
      if (this.hasTopIconTarget) this.topIconTarget.classList.toggle("hidden", !isPastTop)
      if (this.hasDownIconTarget) this.downIconTarget.classList.toggle("hidden", isPastTop)
    }
  }

  // Click handler — direction-aware
  scrollDirection(event) {
    event?.preventDefault()
    if (window.scrollY > 200) {
      window.scrollTo({ top: 0, behavior: "smooth" })
    } else {
      // Find first section after the hero with id="features" or first <section>
      const target = document.getElementById("features") || document.querySelector("section[data-screen-label]")
      if (target) {
        target.scrollIntoView({ behavior: "smooth", block: "start" })
      } else {
        window.scrollBy({ top: window.innerHeight * 0.85, behavior: "smooth" })
      }
    }
  }

  // Lazy reveal sections as they enter the viewport
  observeSections() {
    const sections = document.querySelectorAll(".editorial section, .editorial header.hero")
    if (!("IntersectionObserver" in window) || !sections.length) {
      sections.forEach(s => s.classList.add("visible"))
      return
    }
    sections.forEach(s => s.classList.add("reveal"))
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible")
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.08, rootMargin: "0px 0px -8% 0px" })
    sections.forEach(s => this.observer.observe(s))
  }
}
