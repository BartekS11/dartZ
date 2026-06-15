import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pad", "input", "padButton", "inputButton"]

  connect() {
    this.show(this.defaultView())
  }

  showPad() {
    this.show("pad")
  }

  showInput() {
    this.show("input")
  }

  defaultView() {
    return window.innerWidth < 768 ? "input" : "all"
  }

  show(view) {
    if (view === "all") {
      this.padTarget.classList.remove("mobile-panel-hidden")
      this.inputTarget.classList.remove("mobile-panel-hidden")
      this.setActiveButton(null)
      return
    }

    const showingPad = view === "pad"
    this.padTarget.classList.toggle("mobile-panel-hidden", !showingPad)
    this.inputTarget.classList.toggle("mobile-panel-hidden", showingPad)
    this.setActiveButton(view)
  }

  setActiveButton(view) {
    if (!this.hasPadButtonTarget || !this.hasInputButtonTarget) return

    this.padButtonTarget.classList.toggle("is-active", view === "pad")
    this.inputButtonTarget.classList.toggle("is-active", view === "input")
  }
}
