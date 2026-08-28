import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "hitButton", "misses"]

  connect() {
    this.focusMisses()
    this.boundKeydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown, true)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown, true)
  }

  keydown(event) {
    if (!this.isSpace(event) || event.repeat) return
    if (!this.hasFormTarget || !this.hasHitButtonTarget) return
    if (["TEXTAREA", "SELECT", "BUTTON"].includes(event.target.tagName)) return

    event.preventDefault()
    event.stopPropagation()
    this.hitButtonTarget.click()
  }

  isSpace(event) {
    return event.code === "Space" || event.key === " " || event.key === "Spacebar"
  }

  focusMisses() {
    if (!this.hasMissesTarget) return

    this.missesTarget.focus()
    this.missesTarget.select()
  }
}
