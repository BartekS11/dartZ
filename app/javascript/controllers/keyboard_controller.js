import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "score", "modeBtn", "modeLabel"]
  static values  = { url: String, score: Number, playerId: Number }

  connect() {
    this.currentScore = this.scoreValue
    this.throwStack   = []
    this.mode         = "single" // "single" = one throw at a time, "total" = sum of turn

    this.boundSync = this.syncScoreFromDOM.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundSync)
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
        this.scoreTarget.textContent = parsed
      }
    }, 50)
  }

toggleMode() {
  this.mode = this.mode === "single" ? "total" : "single"
  this.throwStack   = []
  this.currentScore = this.scoreValue
  this.inputTarget.value = ""
  this.scoreTarget.textContent = this.currentScore

  // Animate the toggle switch
  const track = document.getElementById("mode-track")
  const thumb = document.getElementById("mode-thumb")

  if (this.mode === "total") {
    track.style.background = "#dc2626"
    thumb.style.transform  = "translateX(16px)"
    this.modeLabelTarget.textContent     = "TURN TOTAL"
    this.inputTarget.placeholder         = "e.g. 85 (sum of turn)"
  } else {
    track.style.background = "#3f3f46"
    thumb.style.transform  = "translateX(0px)"
    this.modeLabelTarget.textContent     = "SINGLE THROW"
    this.inputTarget.placeholder         = "20  d20  t20  b  db"
  }
}

  preview() {
    const raw = this.inputTarget.value.trim()
    if (!raw) {
      this.scoreTarget.textContent = this.currentScore
      return
    }

    if (this.mode === "total") {
      const total = parseInt(raw, 10)
      if (isNaN(total)) return
      const remaining = this.currentScore - total
      this.scoreTarget.textContent = remaining < 0 ? "BUST" : remaining
    } else {
      const parsed = this.parseThrow(raw)
      if (!parsed) return
      const remaining = this.currentScore - parsed.points
      this.scoreTarget.textContent = remaining < 0 ? "BUST" : remaining
    }
  }

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

  // ── Single throw mode ──────────────────────────────────────────────────────

  submitSingle(raw) {
    const parsed = this.parseThrow(raw)
    if (!parsed) return

    const newScore = this.currentScore - parsed.points
    if (newScore < 0) {
      this.inputTarget.value = ""
      this.scoreTarget.textContent = this.currentScore
      return
    }

    this.throwStack.push({ parsed, points: parsed.points })
    this.currentScore = newScore
    this.inputTarget.value = ""
    this.scoreTarget.textContent = this.currentScore

    this.submitThrow(parsed.segment, parsed.multiplier)
  }

  // ── Turn total mode ────────────────────────────────────────────────────────

  submitTotal(raw) {
    const total = parseInt(raw, 10)
    if (isNaN(total) || total < 0) return

    const newScore = this.currentScore - total
    if (newScore < 0) {
      this.inputTarget.value = ""
      this.scoreTarget.textContent = this.currentScore
      return
    }

    // Submit as a single "summary" throw — segment=0, multiplier=single, points override
    this.submitThrow(null, null, total)
  }

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

    form.requestSubmit()
    this.inputTarget.value = ""
  }

  undoLastThrow() {
    if (this.throwStack.length === 0) return
    // undo not supported in total mode
    if (this.mode === "total") return

    const last = this.throwStack.pop()
    this.currentScore += last.points
    this.scoreTarget.textContent = this.currentScore
  }

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