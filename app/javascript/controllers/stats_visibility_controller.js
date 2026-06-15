import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["details"]

  connect() {
    const desktop = window.innerWidth >= 768
    this.detailsTargets.forEach((detail) => {
      detail.open = desktop
    })
  }
}
