import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "panelIcon", "all", "label"]

  // Toggle the whole panel open/closed
  togglePanel() {
    const isHidden = this.panelTarget.classList.contains("hidden")
    if (isHidden) {
      this.panelTarget.classList.remove("hidden")
      this.panelIconTarget.textContent = "▲ THROWS"
    } else {
      this.panelTarget.classList.add("hidden")
      this.panelIconTarget.textContent = "▼ THROWS"
    }
  }

  // Toggle older throws inside the panel
  toggle(event) {
    event.stopPropagation() // prevent triggering togglePanel
    const isHidden = this.allTarget.classList.contains("hidden")
    if (isHidden) {
      this.allTarget.classList.remove("hidden")
      this.labelTarget.textContent = "▲ HIDE OLDER"
    } else {
      this.allTarget.classList.add("hidden")
      this.labelTarget.textContent = "▼ SHOW OLDER"
    }
  }
}