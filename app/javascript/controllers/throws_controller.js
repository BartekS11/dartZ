import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recent", "all"]

  toggle(event) {
    event.preventDefault()

    this.allTarget.classList.toggle("hidden")
    this.recentTarget.classList.toggle("hidden")

    event.target.textContent =
      this.allTarget.classList.contains("hidden")
        ? "Show all"
        : "Show less"
  }
}
