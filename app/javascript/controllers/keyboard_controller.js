import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.currentThrows = [] 
  }
  static targets = ["input"]
  static values = { url: String }

  handle(event) {
    if (event.key !== "Enter") return
    event.preventDefault()

    const value = this.inputTarget.value.trim().toLowerCase()
    if (!value) return

    const parsed = this.parseInput(value)
    if (!parsed) {
      alert("Invalid throw. Use 20, d20, t20, b, db")
      return
    }

    this.currentThrows.push(parsed)
    this.submitThrow(parsed)
    this.inputTarget.value = ""

    if (this.currentThrows.length >= 3) {
      alert("Turn complete! Entered 3 throws.")
      this.currentThrows = []
    }
  }

  parseInput(value) {
    if (value === "b") return { segment: 25, multiplier: "single" }
    if (value === "db") return { segment: 25, multiplier: "double" }

    let multiplier = "single"
    let segment = value

    if (value.startsWith("d")) {
      multiplier = "double"
      segment = value.slice(1)
    }

    if (value.startsWith("t")) {
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
