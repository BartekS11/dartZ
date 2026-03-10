import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "score"]
  static values = { url: String, score: Number, playerId: Number }

connect() {
  this.currentScore = this.scoreValue
  this.throwStack = []
  this.boundSync = this.syncScoreFromDOM.bind(this)
  document.addEventListener("turbo:before-stream-render", this.boundSync)
}

disconnect() {
  document.removeEventListener("turbo:before-stream-render", this.boundSync)
}
syncScoreFromDOM() {
  // Small delay to let turbo finish updating the DOM
  setTimeout(() => {
    const serverScoreEl = document.getElementById(`player-${this.playerIdValue}-score`)
    if (!serverScoreEl) return
    const parsed = parseInt(serverScoreEl.textContent.trim(), 10)
    if (!isNaN(parsed)) {
      this.currentScore = parsed
      this.scoreTarget.textContent = parsed
    }
  }, 50)
}
  preview() {
    const value = this.inputTarget.value.trim().toLowerCase()
    if (!value) {
      this.scoreTarget.textContent = this.currentScore
      return
    }
    const parsed = this.parseInput(value)
    if (!parsed) {
      this.scoreTarget.textContent = this.currentScore
      return
    }
    const points = this.calculatePoints(parsed)
    const previewScore = this.currentScore - points
    this.scoreTarget.textContent = previewScore >= 0 ? previewScore : this.currentScore
  }

  handle(event) {
    if (event.key !== "Enter") return
    event.preventDefault()

    const value = this.inputTarget.value.trim().toLowerCase()
    if (!value) return

    const parsed = this.parseInput(value)
    if (!parsed) return

    const points = this.calculatePoints(parsed)
    const newScore = this.currentScore - points
    if (newScore < 0) return  // bust — don't submit

    // Optimistic UI update — also update currentScore immediately
    // so the next throw calculates from the correct base
    this.currentScore = newScore
    this.scoreTarget.textContent = newScore
    this.throwStack.push({ parsed, points })
    this.inputTarget.value = ""

    this.submitThrow(parsed)
  }

  undoLastThrow() {
    if (!this.throwStack.length) return
    const { parsed, points } = this.throwStack.pop()
    this.currentScore += points
    this.scoreTarget.textContent = this.currentScore

    fetch(`${this.urlValue}/undo`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ throw: parsed })
    })
  }

  calculatePoints(data) {
    if (data.segment === 25) return data.multiplier === "double" ? 50 : 25
    if (data.multiplier === "double") return data.segment * 2
    if (data.multiplier === "triple") return data.segment * 3
    return data.segment
  }

  parseInput(value) {
    if (value === "b") return { segment: 25, multiplier: "single" }
    if (value === "db") return { segment: 25, multiplier: "double" }

    let multiplier = "single"
    let segment = value

    if (value.startsWith("d")) {
      multiplier = "double"
      segment = value.slice(1)
    } else if (value.startsWith("t")) {
      multiplier = "triple"
      segment = value.slice(1)
    }

    const number = parseInt(segment, 10)
    if (isNaN(number) || number < 1 || number > 20) return null
    return { segment: number, multiplier }
  }

  submitThrow(data) {
    document.getElementById("keyboard-segment").value = data.segment
    document.getElementById("keyboard-multiplier").value = data.multiplier
    document.getElementById("keyboard-form").requestSubmit()
  }
}