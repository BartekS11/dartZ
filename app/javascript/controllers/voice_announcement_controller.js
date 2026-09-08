import { Controller } from "@hotwired/stimulus"

const playedEvents = new Set()

export default class extends Controller {
  static values = { eventId: String, src: String }

  connect() {
    if (!this.eventIdValue || !this.srcValue || playedEvents.has(this.eventIdValue)) {
      this.element.remove()
      return
    }

    playedEvents.add(this.eventIdValue)

    const audio = new Audio(this.srcValue)
    audio.play().catch(() => {})
    this.element.remove()
  }
}
