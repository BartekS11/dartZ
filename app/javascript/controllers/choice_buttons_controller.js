import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  select(event) {
    event.preventDefault()

    const button = event.currentTarget
    this.inputTarget.value = button.dataset.choiceValue
    this.buttonTargets.forEach((candidate) => candidate.classList.remove("is-selected"))
    button.classList.add("is-selected")
  }
}
