import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values  = { url: String, score: Number, playerId: Number }

  connect() {
    this.currentScore = this.scoreValue

    this.boundSync = this.syncScoreFromDOM.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundSync)

    if (this.hasInputTarget) {
      this.inputTarget.placeholder = "e.g. 85 (turn total)"
      this.inputTarget.focus()
    }

    this.boundUndo = this.handleUndo.bind(this)
    document.addEventListener("keydown", this.boundUndo)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundSync)
    document.removeEventListener("keydown", this.boundUndo)
  }
handleUndo(e) {
  if ((e.ctrlKey || e.metaKey) && e.key === "z") {
    e.preventDefault()
    this.undoLastThrow()
  }
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

    const total       = parseInt(raw, 10)
    if (isNaN(total)) return
    const remaining   = this.currentScore - total
    const maxPossible = this.getMaxPossible()

    if (total > maxPossible || remaining < 0) {
      this.updateScoreCardPreview(null)
    } else {
      this.updateScoreCardPreview(remaining)
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

    this.submitTotal(raw)
  }

  // ── Turn total ─────────────────────────────────────────────────────────────

  submitTotal(raw) {
    const total = parseInt(raw, 10)
    if (isNaN(total) || total < 0) return

    const maxPossible = this.getMaxPossible()

    if (total > maxPossible || total > this.currentScore) {
      this.inputTarget.value = ""
      this.resetScoreCardPreview()
      return
    }

    this.inputTarget.value = ""
    this.resetScoreCardPreview()
    this.submitThrow(null, null, total)
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

submitThrow(segment, multiplier, totalPoints) {
  const form      = document.getElementById("keyboard-form")
  const segInput  = document.getElementById("keyboard-segment")
  const multInput = document.getElementById("keyboard-multiplier")
  const totInput  = document.getElementById("keyboard-total")

  if (totalPoints !== undefined) {
    segInput.value  = ""
    multInput.value = ""
    if (totInput) totInput.value = totalPoints
  } else {
    segInput.value  = segment
    multInput.value = multiplier
    if (totInput) totInput.value = ""
  }

  this.resetScoreCardPreview()
  this.inputTarget.value = ""
  form.requestSubmit()

  // Wait for turbo stream to finish re-rendering then focus
  const focusInput = () => {
    const input = document.querySelector('[data-keyboard-target="input"]')
    if (input) {
      input.focus()
    } else {
      requestAnimationFrame(focusInput)
    }
  }
  requestAnimationFrame(focusInput)
}

  // ── Undo ───────────────────────────────────────────────────────────────────

  async undoLastThrow() {
    const form   = document.getElementById("keyboard-form")
    const turnId = form?.action.match(/turns\/(\d+)/)?.[1]
    if (!turnId) return

    const response = await fetch(`/turns/${turnId}/throws/last`, {
      method:  "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        "Accept":       "text/vnd.turbo-stream.html",
        "X-Undo-Mode":  "total"
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }

}
