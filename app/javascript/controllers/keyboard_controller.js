import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "skipButton"]
  static values = {
    url: String,
    score: Number,
    doubleOut: Boolean,
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
      this.updateCheckoutPreview(null)
    } else {
      el.textContent = value
      el.style.color = "#f87171"
      el.style.opacity = "0.75"
      this.updateCheckoutPreview(value)
    }
  }

  updateCheckoutPreview(score) {
    const el = document.getElementById(`player-${this.playerIdValue}-checkout`)
    if (!el) return

    if (score === null || !this.doubleOutValue) {
      el.textContent = ""
      el.classList.add("is-empty")
      return
    }

    const suggestion = this.checkoutSuggestion(score, this.getPreviewDartsRemaining())
    el.textContent = suggestion ? suggestion.join(" · ") : ""
    el.classList.toggle("is-empty", !suggestion)
  }

  getPreviewDartsRemaining() {
    return Math.max(0, 3 - this.getThrowsCount() - 1)
  }

  checkoutSuggestion(score, dartsRemaining) {
    const table = {
      170:["T20","T20","Bull"],167:["T20","T19","Bull"],164:["T20","T18","Bull"],161:["T20","T17","Bull"],160:["T20","T20","D20"],158:["T20","T20","D19"],157:["T20","T19","D20"],156:["T20","T20","D18"],155:["T20","T19","D19"],154:["T20","T18","D20"],153:["T20","T19","D18"],152:["T20","T20","D16"],151:["T20","T17","D20"],150:["T20","T18","D18"],149:["T20","T19","D16"],148:["T20","T20","D14"],147:["T20","T17","D18"],146:["T20","T18","D16"],145:["T20","T19","D14"],144:["T20","T20","D12"],143:["T20","T17","D16"],142:["T20","T14","D20"],141:["T20","T19","D12"],140:["T20","T20","D10"],139:["T20","T13","D20"],138:["T20","T18","D12"],137:["T20","T19","D10"],136:["T20","T20","D8"],135:["T20","T17","D12"],134:["T20","T14","D16"],133:["T20","T19","D8"],132:["T20","T16","D12"],131:["T20","T13","D16"],130:["T20","T18","D8"],129:["T20","T19","D6"],128:["T20","T16","D10"],127:["T20","T17","D8"],126:["T20","T19","D4"],125:["T20","T15","D10"],124:["T20","T16","D8"],123:["T20","T13","D12"],122:["T18","T16","D8"],121:["T20","T11","D14"],120:["T20","S20","D20"],119:["T19","T12","D13"],118:["T20","S18","D20"],117:["T20","S17","D20"],116:["T20","S16","D20"],115:["T20","S15","D20"],114:["T20","S14","D20"],113:["T20","S13","D20"],112:["T20","S12","D20"],111:["T20","S11","D20"],110:["T20","S10","D20"],109:["T20","S9","D20"],108:["T20","S8","D20"],107:["T19","S10","D20"],106:["T20","S6","D20"],105:["T20","S5","D20"],104:["T20","S4","D20"],103:["T20","S3","D20"],102:["T20","S2","D20"],101:["T20","S1","D20"],100:["T20","D20"],99:["T19","S10","D16"],98:["T20","D19"],97:["T19","D20"],96:["T20","D18"],95:["T19","D19"],94:["T18","D20"],93:["T19","D18"],92:["T20","D16"],91:["T17","D20"],90:["T18","D18"],89:["T19","D16"],88:["T20","D14"],87:["T17","D18"],86:["T18","D16"],85:["T15","D20"],84:["T20","D12"],83:["T17","D16"],82:["T14","D20"],81:["T19","D12"],80:["T20","D10"],79:["T13","D20"],78:["T20","D9"],77:["T19","D10"],76:["T20","D8"],75:["T17","D12"],74:["T14","D16"],73:["T19","D8"],72:["T16","D12"],71:["T13","D16"],70:["T18","D8"],69:["T19","D6"],68:["T20","D4"],67:["T17","D8"],66:["T10","D18"],65:["T19","D4"],64:["T16","D8"],63:["T13","D12"],62:["T10","D16"],61:["T15","D8"],60:["S20","D20"],59:["S19","D20"],58:["S18","D20"],57:["S17","D20"],56:["T16","D4"],55:["S15","D20"],54:["S14","D20"],53:["S13","D20"],52:["S12","D20"],51:["S11","D20"],50:["Bull"],49:["S9","D20"],48:["S16","D16"],47:["S15","D16"],46:["S14","D16"],45:["S13","D16"],44:["S12","D16"],43:["S11","D16"],42:["S10","D16"],41:["S9","D16"],40:["D20"],39:["S7","D16"],38:["D19"],37:["S5","D16"],36:["D18"],35:["S3","D16"],34:["D17"],33:["S1","D16"],32:["D16"],31:["S15","D8"],30:["D15"],29:["S13","D8"],28:["D14"],27:["S11","D8"],26:["D13"],25:["S9","D8"],24:["D12"],23:["S7","D8"],22:["D11"],21:["S5","D8"],20:["D10"],19:["S3","D8"],18:["D9"],17:["S1","D8"],16:["D8"],15:["S7","D4"],14:["D7"],13:["S5","D4"],12:["D6"],11:["S3","D4"],10:["D5"],9:["S1","D4"],8:["D4"],7:["S3","D2"],6:["D3"],5:["S1","D2"],4:["D2"],3:["S1","D1"],2:["D1"]
    }
    const path = table[score]
    if (!path || path.length > dartsRemaining) return null
    return path
  }

  resetScoreCardPreview() {
    const el = document.getElementById(`player-${this.playerIdValue}-score`)
    if (!el) return

    el.textContent = this.currentScore
    el.style.color = ""
    el.style.opacity = ""

    const checkout = document.getElementById(`player-${this.playerIdValue}-checkout`)
    if (checkout) {
      checkout.textContent = checkout.dataset.originalCheckout || ""
      checkout.classList.toggle("is-empty", !checkout.textContent)
    }
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
