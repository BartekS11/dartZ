import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "modeBtn", "modeLabel"]
  static values  = { url: String, score: Number, playerId: Number }

connect() {
  this.currentScore = this.scoreValue
  this.throwStack   = []
  this.mode         = localStorage.getItem("dartz_input_mode") || "single"

  this.boundSync = this.syncScoreFromDOM.bind(this)
  document.addEventListener("turbo:before-stream-render", this.boundSync)

  this.applyMode()

  // Autofocus input on connect (fires on initial load and after turbo re-render)
  if (this.hasInputTarget) this.inputTarget.focus()
}

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundSync)
  }

  syncScoreFromDOM() {
    setTimeout(() => {
      const el = document.getElementById(`player-${this.playerIdValue}-score`)
      if (!el) return
      const parsed = parseInt(el.textContent.trim(), 10)
      if (!isNaN(parsed)) {
        this.currentScore = parsed
        this.resetScoreCardPreview()
      }
    }, 50)
  }

  // ── Mode ───────────────────────────────────────────────────────────────────

  applyMode() {
    const track = document.getElementById("mode-track")
    const thumb = document.getElementById("mode-thumb")

    if (this.mode === "total") {
      if (track) track.style.background = "#dc2626"
      if (thumb) thumb.style.transform  = "translateX(16px)"
      if (this.hasModeLabelTarget) this.modeLabelTarget.textContent = "TURN TOTAL"
      if (this.hasInputTarget)     this.inputTarget.placeholder     = "e.g. 85 (sum of turn)"
    } else {
      if (track) track.style.background = "#3f3f46"
      if (thumb) thumb.style.transform  = "translateX(0px)"
      if (this.hasModeLabelTarget) this.modeLabelTarget.textContent = "SINGLE THROW"
      if (this.hasInputTarget)     this.inputTarget.placeholder     = "20  d20  t20  b  db"
    }
  }

  toggleMode() {
    this.mode = this.mode === "single" ? "total" : "single"
    localStorage.setItem("dartz_input_mode", this.mode)

    this.throwStack        = []
    this.inputTarget.value = ""
    this.resetScoreCardPreview()

    this.applyMode()
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  getThrowsCount() {
    const form = document.getElementById("keyboard-form")
    return parseInt(form?.dataset?.throwsCount || 0)
  }

  getMaxPossible() {
    const dartsRemaining = 3 - this.getThrowsCount()
    return dartsRemaining * 60
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  preview() {
    const raw = this.inputTarget.value.trim()

    if (!raw) {
      this.resetScoreCardPreview()
      return
    }

    if (this.mode === "total") {
      const total      = parseInt(raw, 10)
      if (isNaN(total)) return
      const remaining  = this.currentScore - total
      const maxPossible = this.getMaxPossible()

      if (total > maxPossible || remaining < 0) {
        this.updateScoreCardPreview(null) // BUST
      } else {
        this.updateScoreCardPreview(remaining)
      }
    } else {
      const parsed = this.parseThrow(raw)
      if (!parsed) return
      const remaining = this.currentScore - parsed.points
      this.updateScoreCardPreview(remaining < 0 ? null : remaining)
    }
  }

  updateScoreCardPreview(value) {
    const el = document.getElementById(`player-${this.playerIdValue}-score`)
    if (!el) return

    if (value === null) {
      el.textContent   = "BUST"
      el.style.color   = "#ef4444"
      el.style.opacity = "0.6"
    } else {
      el.textContent   = value
      el.style.color   = "#f87171"
      el.style.opacity = "0.75"
    }
  }

  resetScoreCardPreview() {
    const el = document.getElementById(`player-${this.playerIdValue}-score`)
    if (!el) return
    el.textContent   = this.currentScore
    el.style.color   = ""
    el.style.opacity = ""
  }

  // ── Input handling ─────────────────────────────────────────────────────────

  handle(e) {
    if (e.key !== "Enter") return
    e.preventDefault()

    const raw = this.inputTarget.value.trim()
    if (!raw) return

    if (this.mode === "total") {
      this.submitTotal(raw)
    } else {
      this.submitSingle(raw)
    }
  }

  // ── Single throw ───────────────────────────────────────────────────────────

  submitSingle(raw) {
    const parsed = this.parseThrow(raw)
    if (!parsed) return

    this.throwStack.push({ points: parsed.points })
    this.inputTarget.value = ""
    this.resetScoreCardPreview()

    this.submitThrow(parsed.segment, parsed.multiplier)
  }

  // ── Turn total ─────────────────────────────────────────────────────────────

  submitTotal(raw) {
    const total       = parseInt(raw, 10)
    if (isNaN(total) || total < 0) return

    const maxPossible = this.getMaxPossible()

    // Reject if impossible in remaining darts or busts score
    if (total > maxPossible || total > this.currentScore) {
      this.inputTarget.value = ""
      this.resetScoreCardPreview()
      return
    }

    this.inputTarget.value = ""
    this.resetScoreCardPreview()
    this.submitThrow(null, null, total)
  }

  this.resetScoreCardPreview()
  this.inputTarget.value = ""

  // Focus after turbo stream re-renders the input
  document.addEventListener("turbo:after-stream-render", () => {
    const input = document.querySelector('[data-keyboard-target="input"]')
    if (input) input.focus()
  }, { once: true })

  form.requestSubmit()
}

  // ── Undo ───────────────────────────────────────────────────────────────────

  async undoLastThrow() {
    this.throwStack.pop()

    const form   = document.getElementById("keyboard-form")
    const turnId = form?.action.match(/turns\/(\d+)/)?.[1]
    if (!turnId) return

    const response = await fetch(`/turns/${turnId}/throws/last`, {
      method:  "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        "Accept":       "text/vnd.turbo-stream.html",
        "X-Undo-Mode":  this.mode
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }

  // ── Parse ──────────────────────────────────────────────────────────────────

  parseThrow(raw) {
    raw = raw.toLowerCase().trim()
    if (raw === "db" || raw === "bull2") return { segment: 25, multiplier: "double", points: 50 }
    if (raw === "b"  || raw === "bull")  return { segment: 25, multiplier: "single", points: 25 }

    const m = raw.match(/^(d|t)?(\d+)$/)
    if (!m) return null

    const prefix = m[1]
    const num    = parseInt(m[2], 10)
    if (num < 1 || num > 20) return null

    const multiplierMap = { d: "double", t: "triple", undefined: "single" }
    const multiplier    = multiplierMap[prefix] || "single"
    const pointsMap     = { single: 1, double: 2, triple: 3 }
    const points        = num * pointsMap[multiplier]

    return { segment: num, multiplier, points }
  }
}
