import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { statusUrl: String, interval: { type: Number, default: 5000 } }

  connect() {
    this.boundVisibilityChange = () => this.handleVisibilityChange()
    document.addEventListener("visibilitychange", this.boundVisibilityChange)
    this.scheduleCheck(0)
  }

  disconnect() {
    this.clearTimer()
    document.removeEventListener("visibilitychange", this.boundVisibilityChange)
  }

  scheduleCheck(delay = this.intervalValue) {
    this.clearTimer()
    if (document.hidden) return

    this.timer = window.setTimeout(() => this.check(), delay)
  }

  clearTimer() {
    if (this.timer) window.clearTimeout(this.timer)
    this.timer = null
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.clearTimer()
    } else {
      this.scheduleCheck(0)
    }
  }

  async check() {
    if (!this.statusUrlValue || this.checking) return

    this.checking = true
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const data = await response.json()
      if (data.joined && data.match_url) {
        window.location.href = data.match_url
        return
      }
    } finally {
      this.checking = false
      this.scheduleCheck()
    }
  }

  copy(event) {
    const url = event.currentTarget.dataset.url
    navigator.clipboard?.writeText(url)
    event.currentTarget.textContent = "Copied"
  }
}
