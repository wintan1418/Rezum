import { Controller } from "@hotwired/stimulus"

// Framer-Motion-style scroll reveals for server-rendered pages.
// Mount once on a page wrapper. Elements opt in via:
//   data-reveal            -> rise + fade + unblur (default variant)
//   data-reveal="left"     -> slide in from the left
//   data-reveal="right"    -> slide in from the right
//   data-reveal="scale"    -> scale up
//   data-reveal-group      -> every direct child becomes a staggered reveal
// .sect-head children are auto-staggered. Styling lives in CSS under
// [data-reveal].reveal-init; stagger uses the --reveal-i custom property.
export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.markGroups()
    const items = this.element.querySelectorAll("[data-reveal]")
    if (!items.length) return

    this.pending = new Set()

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        this.revealItem(entry.target)
      })
    }, { threshold: 0.1, rootMargin: "0px 0px -4% 0px" })

    items.forEach((item) => {
      // Never hide content already above the fold on load
      if (item.getBoundingClientRect().top < window.innerHeight * 0.6) return
      item.classList.add("reveal-init")
      this.pending.add(item)
      this.observer.observe(item)
    })

    // Safety net: fast scrolls and anchor jumps can outrun the observer —
    // anything that has passed above the viewport reveals immediately.
    this.onScroll = () => {
      if (this.scrollCheck) return
      this.scrollCheck = setTimeout(() => {
        this.scrollCheck = null
        this.pending.forEach((item) => {
          if (item.getBoundingClientRect().bottom < 0) this.revealItem(item)
        })
      }, 400)
    }
    window.addEventListener("scroll", this.onScroll, { passive: true })
  }

  revealItem(item) {
    item.classList.add("is-revealed")
    this.observer.unobserve(item)
    this.pending.delete(item)
    if (this.pending.size === 0) window.removeEventListener("scroll", this.onScroll)
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("scroll", this.onScroll)
    clearTimeout(this.scrollCheck)
  }

  markGroups() {
    this.element.querySelectorAll("[data-reveal-group]").forEach((group) => {
      Array.from(group.children).forEach((child, i) => {
        if (!child.hasAttribute("data-reveal")) {
          child.setAttribute("data-reveal", group.getAttribute("data-reveal-group") || "")
        }
        child.style.setProperty("--reveal-i", i)
      })
    })

    this.element.querySelectorAll(".sect-head").forEach((head) => {
      Array.from(head.children).forEach((child, i) => {
        if (!child.hasAttribute("data-reveal")) child.setAttribute("data-reveal", "")
        child.style.setProperty("--reveal-i", i)
      })
    })
  }
}
