import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "skipButton"]
  static values = {
    url: String,
    score: Number,
    playerId: Number,
    currentPlayerId: Number,
    turnActivityAt: String,
    afkTimeoutSeconds: { type: Number, default: 120 }
  }

  connect() {
    this.currentScore = this.scoreValue

    this.boundSync = this.syncScoreFromDOM.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundSync)

    this.boundRender = this.afterRender.bind(this)
    document.addEventListener("turbo:render", this.boundRender)

    this.boundUndo = this.handleUndo.bind(this)
    document.addEventListener("keydown", this.boundUndo)

    this.afkTimer = window.setInterval(() => this.updateTurnLock(), 1000)

    this.afterRender()
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundSync)
    document.removeEventListener("turbo:render", this.boundRender)
    document.removeEventListener("keydown", this.boundUndo)
    window.clearInterval(this.afkTimer)
  }

  afterRender() {
    requestAnimationFrame(() => {
      this.updateTurnLock()

      if (!this.hasInputTarget) return
      if (this.inputTarget.disabled) return

      this.inputTarget.focus()
      this.inputTarget.select()
    })
  }

  handleUndo(e) {
    if ((e.ctrlKey || e.metaKey) && e.key === "z") {
      e.preventDefault()
      this.undoLastThrow()
    }
  }

  updateTurnLock() {
    const matchView = document.getElementById("match-live")
    if (!matchView || !this.hasInputTarget) return

    const remoteInvite = matchView.dataset.matchViewRemoteInviteValue === "true"
    if (!remoteInvite) {
      this.element.classList.remove("is-disabled")
      this.inputTarget.disabled = false
      this.inputTarget.placeholder = "Enter score"
      const undo = this.element.querySelector(".btn-undo")
      if (undo) undo.disabled = false
      if (this.hasSkipButtonTarget) this.skipButtonTarget.classList.add("hidden")
      return
    }

    const myPlayerId = Number(matchView.dataset.matchViewMyPlayerIdValue || 0)
    if (!myPlayerId) return

    const myTurn = myPlayerId === this.currentPlayerIdValue
    const canSkip = !myTurn && this.afkExpired()

    this.element.classList.toggle("is-disabled", !myTurn)

    this.inputTarget.disabled = !myTurn
    this.inputTarget.placeholder = myTurn
      ? "Enter score"
      : this.waitingPlaceholder(canSkip)

    const undo = this.element.querySelector(".btn-undo")
    if (undo) undo.disabled = !myTurn

    if (this.hasSkipButtonTarget) {
      this.skipButtonTarget.classList.toggle("hidden", myTurn)
      this.skipButtonTarget.disabled = !canSkip
      this.skipButtonTarget.textContent = canSkip ? "Skip stale turn (0)" : `Skip available in ${this.afkSecondsRemaining()}s`
    }
  }

  waitingPlaceholder(canSkip) {
    return canSkip ? "Opponent AFK? You can skip this turn." : `Waiting for opponent… ${this.afkSecondsRemaining()}s to skip`
  }

  afkExpired() {
    return this.afkSecondsRemaining() <= 0
  }

  afkSecondsRemaining() {
    if (!this.turnActivityAtValue) return this.afkTimeoutSecondsValue

    const activityAt = Date.parse(this.turnActivityAtValue)
    if (Number.isNaN(activityAt)) return this.afkTimeoutSecondsValue

    return Math.max(0, Math.ceil((activityAt + this.afkTimeoutSecondsValue * 1000 - Date.now()) / 1000))
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

  getThrowsCount() {
    const form = document.getElementById("keyboard-form")
    return parseInt(form?.dataset?.throwsCount || 0)
  }

  getMaxPossible() {
    return (3 - this.getThrowsCount()) * 60
  }

  preview() {
    if (this.inputTarget.disabled) return

    const raw = this.inputTarget.value.trim()

    if (!raw) {
      this.resetScoreCardPreview()
      return
    }

    const total = parseInt(raw, 10)
    if (isNaN(total)) return

    const remaining = this.currentScore - total
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
      el.textContent = "BUST"
      el.style.color = "#ef4444"
      el.style.opacity = "0.6"
    } else {
      el.textContent = value
      el.style.color = "#f87171"
      el.style.opacity = "0.75"
    }
  }

  resetScoreCardPreview() {
    const el = document.getElementById(`player-${this.playerIdValue}-score`)
    if (!el) return

    el.textContent = this.currentScore
    el.style.color = ""
    el.style.opacity = ""
  }

  handle(e) {
    if (this.inputTarget.disabled) return

    if (e.key !== "Enter") return

    e.preventDefault()
    this.submitInput()
  }

  submitInput() {
    if (this.inputTarget.disabled) return

    const raw = this.inputTarget.value.trim()
    if (!raw) return

    this.submitTotal(raw)
  }

  submitTotal(raw) {
    const total = parseInt(raw, 10)

    if (isNaN(total) || total < 0) return

    if (total > this.getMaxPossible() || total > this.currentScore) {
      this.inputTarget.value = ""
      this.resetScoreCardPreview()
      return
    }

    this.inputTarget.value = ""
    this.resetScoreCardPreview()

    this.submitThrow(null, null, total)
  }

  submitThrow(segment, multiplier, totalPoints, { force = false } = {}) {
    if (this.inputTarget.disabled && !force) return

    const form = document.getElementById("keyboard-form")
    const segInput = document.getElementById("keyboard-segment")
    const multInput = document.getElementById("keyboard-multiplier")
    const totInput = document.getElementById("keyboard-total")

    if (totalPoints !== undefined) {
      segInput.value = ""
      multInput.value = ""
      totInput.value = totalPoints
    } else {
      segInput.value = segment
      multInput.value = multiplier
      totInput.value = ""
    }

    this.resetScoreCardPreview()
    this.inputTarget.value = ""

    form.requestSubmit()
  }

  skipAfkTurn() {
    if (!this.afkExpired()) return

    this.submitThrow(null, null, 0, { force: true })
  }

  async undoLastThrow() {
    if (this.inputTarget.disabled) return

    const form = document.getElementById("keyboard-form")
    const turnId = form?.action.match(/turns\/([^/]+)/)?.[1]
    if (!turnId) return

    const matchView = document.querySelector("[data-match-view-my-player-id-value]")
    const actorPlayerId = matchView?.dataset?.matchViewMyPlayerPublicIdValue

    const response = await fetch(`/turns/${turnId}/throws/last`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        "Accept": "text/vnd.turbo-stream.html",
        "X-Undo-Mode": "total",
        "X-Actor-Player-Id": actorPlayerId || ""
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }
}
