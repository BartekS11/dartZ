import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "label"]

  connect() {
    this.apply(this.currentTheme())
  }

  toggle() {
    this.apply(this.currentTheme() === "dark" ? "light" : "dark")
  }

  currentTheme() {
    return localStorage.getItem("dartz_theme_mode") || document.documentElement.dataset.theme || "dark"
  }

  apply(theme) {
    document.documentElement.dataset.theme = theme
    localStorage.setItem("dartz_theme_mode", theme)

    if (this.hasLabelTarget) this.labelTarget.textContent = theme === "dark" ? "Dark" : "Light"
    if (this.hasIconTarget) this.iconTarget.textContent = theme === "dark" ? "◐" : "◑"
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-pressed", theme === "light")
  }
}
