# Rezumfit — UI Handover Doc

**For:** Claude Code (or any frontend engineer rebuilding from this design)
**Source of truth:** `Rezumfit.html` in this project
**Direction:** Cold-modern editorial. Architectural type, porcelain ground, single electric-cobalt accent. No warm tones, no cream, no gradients, no glass.

---

## 1. Design tokens

Copy these into your CSS / Tailwind config / theme file verbatim.

### Color
| Token | Value | Use |
|---|---|---|
| `--ink` | `#14171C` | Primary text, dark surfaces, primary buttons |
| `--paper` | `#EDEEF0` | Page background (cool porcelain) |
| `--paper-2` | `#E2E4E8` | Secondary surface / hover state on neutral cards |
| `--muted` | `#6A6E78` | Secondary copy, metadata |
| `--graphite` | `#3A3F49` | Tertiary text, subtle dividers on dark surfaces |
| `--accent` | `#2540FF` | Single accent. Italic emphasis, links, score bars, primary CTA on dark |
| `--accent-soft` | `#DCE0FF` | Reserved for future tints — do not use yet |
| `--rule` | `#14171C` | 1px rules and borders (always with low alpha mix) |

**Rules of color use**
- One accent only. Never pair `--accent` with another saturated color.
- Borders are always `color-mix(in oklab, var(--ink) X%, transparent)` — typically 8–14%. Never use solid `--ink` for hairlines.
- The résumé card body is `#FBFBFC` (slightly cooler than paper, reads as "document").
- Dark surfaces (closing CTA, footer, featured pricing tile) use `--ink`. Text on dark uses `--paper` mixed with transparency for hierarchy (`color-mix(in oklab, var(--paper) 60%, transparent)` for muted).

### Typography
Three families, loaded from Google Fonts:

```html
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght,SOFT,WONK@9..144,300..900,0..100,0..1&family=Inter+Tight:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

| Role | Family | Notes |
|---|---|---|
| Display / serif | **Fraunces** (variable) | `font-variation-settings: "opsz" 144, "SOFT" 30, "WONK" 0`. Italics use `"SOFT" 100, "WONK" 1` for the wonky cut — that is the signature move. |
| Body / UI | **Inter Tight** | 300 / 400 / 500 / 600. Default body is 400 / 16px / 1.5. |
| Metadata / mono | **JetBrains Mono** | Always 11px or smaller, uppercase, `letter-spacing: 0.04–0.12em`. |

**Optical sizing matters.** Do not skip the `opsz` axis on Fraunces — it is what makes large display type feel cut for the size. Headings use `opsz 96–144`, mid-headings 36–60, small inline serif uses 24.

**Italic emphasis pattern:** wherever an italic word appears in a heading (e.g. _tailored_, _recast_, _Method_), it gets `color: var(--accent)` and the wonky variation. This is the only way the accent color appears in headings.

### Scale
- Page max-width: `1440px`
- Page padding: `48px` desktop, `24px` mobile
- Section vertical rhythm: `120px` top padding for major sections; `88px` for the hero
- Border-radius: rarely used. Cards = `6–8px`, pills (buttons) = `999px`. The rest is flat.

---

## 2. Component inventory

Each maps to a `<section data-screen-label="…">` in the source. Build them as standalone components.

### a. `<TopNav />`
Sticky, blurred (`backdrop-filter: blur(10px)`), 64px tall. Mark on left (a custom geometric glyph: a circle with a wedge cut, see `nav.top .mark .glyph` for the construction). Center: 4 text links. Right: "Sign in" + dark pill CTA.

### b. `<HeroMasthead />`
- Top row: 4-column metadata grid (Vol/Issue, Edition, For, Filed under) — each with mono label above and Inter Tight value below.
- Headline: massive Fraunces, 2 lines. Second line indented 18% to create the editorial layout shift. Italic word(s) get accent color + wonk axis.
- Sub-grid: 2 columns. Left = lede (24px Fraunces 300, italic-feeling). Right = stacked CTAs (primary pill + ghost link with bottom underline) + mono fineprint.

### c. `<Marquee />`
Infinite horizontal scroll, 60s loop. Track is duplicated for seamless loop. Items separated by `✦` glyphs in accent color. 22px italic Fraunces.

### d. `<ArtifactSection />` — the hero product visual
Two-column: left = the rendered résumé "document"; right = sticky stack of (job-listing card, fit-score card, change-log card).

**`<ResumeArtifact />` — important rules:**
- Aspect ratio `8.5/11`, padding `54px 56px`, background `#FBFBFC`.
- **No stamp. No marks. No highlights. No annotations on the document.** It must read as a clean, type-set résumé. Plain text only.
- Structure: name + role topline, then `<h3>` mono section headers ("Summary", "Experience", "Selected Skills"), then entries in a 90px / 1fr grid (date column + content column).
- Subtle 1px `color-mix` border-tops between entries.

**`<JobListingCard />`** — paper-2 background, "Analyzing" pulse dot in accent color, keyword chips (matched chips invert: ink fill, accent ✓ prefix).

**`<FitScoreCard />`** — `--ink` background, oversized Fraunces numeral with italic `/100` suffix. Animated bar fills to 94% on mount.

**`<ChangeLogCard />`** — dashed border, list of edits each prefixed with a mono tag (REWRITE, SURFACE, METRIC, KEEP).

### e. `<HowItWorks />` (Section II)
Three-column equal grid, separated by 1px hairlines. Each step: mono "Step 0X" + small ASCII diagram + Fraunces heading + muted body. Hover state: cell background shifts to `--paper-2`.

The ASCII diagrams use `<pre class="diagram">` with `font-family: JetBrains Mono`, 10px. Spans `.acc` (accent) and `.moss` (graphite, despite the legacy class name) provide color highlights inside the ASCII.

### f. `<Testimonial />`
Centered. Massive `"` glyph behind the quote at 280px, 8% opacity ink. Blockquote in Fraunces 300, italic-emphasized clause in accent. Mono attribution below.

### g. `<Stats />` — 4-up
Bordered top + bottom. Each cell separated by left-hairline (except first). Numeral in Fraunces 72px with italic units (×, s, k) in accent. Mono label + Fraunces 300 italic descriptor.

### h. `<Pricing />`
3-up grid in a rounded container with 1px gap (achieved by setting the wrapper background to a low-alpha ink color and giving each tile `--paper` background). Featured tile uses `--ink` background. Featured CTA uses accent fill, white text. Bullets use a 6px round dot prefix (no checkmarks — too informal).

### i. `<FAQ />`
Two-column: left = oversized Fraunces section heading; right = list of `<details>` accordions. Summary uses Fraunces 22px, `+` / `–` toggle in mono accent. Hairline dividers, 22px vertical padding per item.

### j. `<ClosingCTA />`
Full-bleed dark section. `--ink` background, `--paper` text. Massive 2-line Fraunces headline (up to 156px) with italic accent emphasis. Two CTAs: accent-filled primary, ghost-on-dark secondary. Below: 3-up meta strip (Made in / Loved by / Backed by).

### k. `<Footer />`
Continues the dark surface from closing CTA. 4-column: brand + 3 link groups. Wordmark in Fraunces 36px, italic accent on the period. Mono legal row at bottom.

---

## 3. Motion

Keep it minimal. Specifically:
- `pulse` keyframe on the "Analyzing" indicator dot (2s infinite, ring expands then fades).
- `fill` keyframe on the fit-score bar (1.6s ease-out, fills to 94%, runs once on mount/in-view).
- `slide` keyframe on the marquee (60s linear infinite).
- Buttons: `translateY(-1px)` on hover, 200ms.
- Step cells: background fade to `--paper-2` on hover, 300ms.

Do **not** add scroll-triggered fades on every section, parallax, or text-split reveals. The composition is supposed to feel still and authored, not animated.

---

## 4. Responsive breakpoint

Single breakpoint at `960px`:
- Page padding drops to 24px.
- All multi-column grids collapse to single column (hero meta becomes 2-up, everything else 1-up).
- Stats: hairlines change from left-borders to top-borders.
- Artifact side panel: `position: sticky` is removed.

Below 600px the hero h1 may need a further font-size tightening — currently uses `clamp(72px, 11vw, 196px)` which behaves correctly down to ~360px, but verify on real devices.

---

## 5. Implementation notes for Claude Code

1. **Stack suggestion.** Next.js 14 + React Server Components for the marketing surface. Tailwind is fine but extend the theme with the tokens above; do not reach for default Tailwind grays — they are too warm.
2. **Component split.** One file per section listed in §2. The artifact section is the heaviest — split into `ResumeArtifact`, `JobListingCard`, `FitScoreCard`, `ChangeLogCard` subcomponents.
3. **Fonts.** Use `next/font` to self-host Fraunces, Inter Tight, JetBrains Mono. Pin Fraunces with the full variable axes (`opsz`, `wght`, `SOFT`, `WONK`) — the design depends on it.
4. **No icons except the arrow in the primary CTA.** Everything else is type or geometric primitives. Resist the urge to add icon-stamped feature cards.
5. **The résumé content is illustrative.** Replace `Mara Okonjo` / `Quill` / `Conduit` etc. with realistic but generic placeholder data — or wire it to real product output if you are building the live integration.
6. **Accessibility.** All accent-on-paper combinations clear WCAG AA at 16px+. The `--muted` on `--paper` clears AA at 14px+. Verify any new combinations.
7. **Preserve the `data-screen-label` attributes** on each section — they are useful for review tooling and instrumentation.

---

## 6. What NOT to do

- No warm beige, cream, parchment, or brass. The previous direction had those — replaced.
- No marks, stamps, watermarks, or annotations on the résumé artifact. It is a clean document.
- No 3-column icon-grid feature section.
- No gradient backgrounds anywhere. The page is flat color.
- No emoji.
- No second accent color. If you need a second state color (success/error), introduce it in dialog/toast components only — not in marketing sections.
- No drop-shadowed pill chips, no glassmorphism, no soft-blurred orbs.

---

## 7. Open questions for the team
- Hero metadata copy ("Vol. 04 — Issue 12") — keep as editorial framing device, or replace with real product version?
- Marquee logos — currently text-set. If real partner logos exist, swap to monochrome SVG marks at ~20px height.
- Pricing — confirm $0 / $14 / $39 are the live numbers.
- Testimonial — needs a real attributed quote before launch.
