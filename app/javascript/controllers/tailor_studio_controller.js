import { Controller } from "@hotwired/stimulus"

// Tailoring Studio: click a missing keyword -> fetch grounded bullet
// suggestions -> apply one -> live match-rate + gap-table update.
export default class extends Controller {
  static targets = ["missingList", "matchedList", "rate", "suggestPanel", "content", "missingCount", "matchedCount"]
  static values = { suggestUrl: String, applyUrl: String }

  selectKeyword(event) {
    const keyword = event.currentTarget.dataset.keyword
    this.highlightChip(event.currentTarget)
    this.renderLoading(keyword)

    this.post(this.suggestUrlValue, { keyword })
      .then((data) => this.renderSuggestions(keyword, data))
      .catch(() => this.renderError())
  }

  apply(event) {
    const button = event.currentTarget
    const { bullet, role, keyword } = button.dataset
    button.disabled = true
    button.textContent = "Adding…"

    this.post(this.applyUrlValue, { bullet, role, keyword })
      .then((data) => {
        this.updateGapTable(data)
        if (this.hasContentTarget && data.content) this.contentTarget.textContent = data.content
        this.renderApplied(keyword)
      })
      .catch(() => {
        button.disabled = false
        button.textContent = "Add to resume"
        this.flashPanelNote("Could not apply the bullet. Please try again.")
      })
  }

  // ---- rendering ----

  renderLoading(keyword) {
    this.suggestPanelTarget.innerHTML = ""
    const wrap = this.node("div", { style: "padding: 32px; text-align: center; color: var(--muted);" })
    wrap.append(
      this.node("div", { class: "font-mono-label", text: keyword }),
      this.node("p", { style: "margin-top: 12px; font-size: 15px;", text: "Checking your resume for real evidence and drafting suggestions…" })
    )
    this.suggestPanelTarget.append(wrap)
  }

  renderSuggestions(keyword, data) {
    this.suggestPanelTarget.innerHTML = ""
    const header = this.node("div", { style: "margin-bottom: 16px;" })
    header.append(
      this.node("span", { class: "font-mono-label", text: `Suggestions — ${keyword}` }),
      this.node("p", { style: "margin-top: 6px; font-size: 14px; color: var(--muted);", text: data.note || "" })
    )
    this.suggestPanelTarget.append(header)

    if (!data.supported || !data.suggestions?.length) {
      const warn = this.node("div", {
        style: "padding: 16px 18px; border: 1px solid color-mix(in oklab, var(--ink) 15%, transparent); border-left: 3px solid var(--accent); border-radius: 6px; background: var(--paper-2); font-size: 14px;",
        text: "No honest way to claim this one — we won't invent experience you don't have. " + (data.note || "")
      })
      this.suggestPanelTarget.append(warn)
      return
    }

    data.suggestions.forEach((s) => {
      const card = this.node("div", { class: "card-paper", style: "padding: 18px; margin-bottom: 12px; background: #FBFBFC;" })
      card.append(this.node("p", { style: "font-size: 15px; line-height: 1.55;", text: s.text }))
      const meta = this.node("div", { style: "display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-top: 12px;" })
      meta.append(this.node("span", { class: "font-mono-label", text: s.role ? `Under: ${s.role}` : "Appends to resume" }))
      const btn = this.node("button", { class: "btn-ink", style: "padding: 8px 16px; font-size: 13px;", text: "Add to resume" })
      btn.dataset.bullet = s.text
      btn.dataset.role = s.role || ""
      btn.dataset.keyword = keyword
      btn.dataset.action = "tailor-studio#apply"
      meta.append(btn)
      card.append(meta)
      this.suggestPanelTarget.append(card)
    })
  }

  renderApplied(keyword) {
    this.suggestPanelTarget.innerHTML = ""
    const done = this.node("div", { style: "padding: 32px; text-align: center;" })
    done.append(
      this.node("div", { class: "font-mono-label", style: "color: var(--accent);", text: "Added" }),
      this.node("p", { style: "margin-top: 10px; font-size: 15px;", text: `"${keyword}" is now in your resume. Pick another keyword to keep going.` })
    )
    this.suggestPanelTarget.append(done)
  }

  renderError() {
    this.suggestPanelTarget.innerHTML = ""
    this.suggestPanelTarget.append(
      this.node("p", { style: "padding: 32px; text-align: center; color: var(--muted); font-size: 14px;", text: "Suggestion generation failed. Please try again." })
    )
  }

  updateGapTable(data) {
    if (this.hasRateTarget && data.match_rate != null) this.rateTarget.textContent = `${data.match_rate}%`
    if (this.hasMissingCountTarget) this.missingCountTarget.textContent = data.missing.length
    if (this.hasMatchedCountTarget) this.matchedCountTarget.textContent = data.matched.length

    this.missingListTarget.innerHTML = ""
    data.missing.forEach((entry) => this.missingListTarget.append(this.missingChip(entry)))
    if (!data.missing.length) {
      this.missingListTarget.append(this.node("p", { style: "font-size: 14px; color: var(--muted);", text: "Nothing missing — full keyword coverage." }))
    }

    this.matchedListTarget.innerHTML = ""
    data.matched.forEach((entry) => this.matchedListTarget.append(this.matchedChip(entry)))
  }

  missingChip(entry) {
    const chip = this.node("button", {
      class: "tailor-chip",
      style: "display: inline-flex; align-items: center; gap: 6px; padding: 7px 14px; margin: 0 8px 8px 0; background: var(--accent-soft); color: var(--ink); border: 1px solid transparent; border-radius: 999px; font-size: 13px; cursor: pointer;",
      text: entry.term
    })
    chip.dataset.keyword = entry.term
    chip.dataset.action = "tailor-studio#selectKeyword"
    return chip
  }

  matchedChip(entry) {
    return this.node("span", {
      style: "display: inline-flex; align-items: center; gap: 6px; padding: 7px 14px; margin: 0 8px 8px 0; background: transparent; border: 1px solid color-mix(in oklab, var(--ink) 15%, transparent); border-radius: 999px; font-size: 13px; color: var(--muted);",
      text: entry.count > 1 ? `${entry.term} ×${entry.count}` : entry.term
    })
  }

  highlightChip(chip) {
    this.missingListTarget.querySelectorAll(".tailor-chip").forEach((c) => (c.style.borderColor = "transparent"))
    chip.style.borderColor = "var(--accent)"
  }

  flashPanelNote(message) {
    this.suggestPanelTarget.prepend(this.node("p", { style: "color: var(--accent); font-size: 13px; margin-bottom: 10px;", text: message }))
  }

  // ---- helpers ----

  node(tag, { class: className, style, text } = {}) {
    const el = document.createElement(tag)
    if (className) el.className = className
    if (style) el.style.cssText = style
    if (text != null) el.textContent = text
    return el
  }

  post(url, body) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        "Accept": "application/json"
      },
      body: JSON.stringify(body)
    }).then((response) => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return response.json()
    })
  }
}
