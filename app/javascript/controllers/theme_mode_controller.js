import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label"]

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
    document.documentElement.classList.toggle("dark", theme === "dark")
    localStorage.setItem("dartz_theme_mode", theme)

    const nextTheme = theme === "dark" ? "light" : "dark"
    const nextThemeLabel = `${nextTheme.charAt(0).toUpperCase()}${nextTheme.slice(1)} theme`

    if (this.hasLabelTarget) this.labelTarget.textContent = nextThemeLabel
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", theme === "light")
      this.buttonTarget.setAttribute("aria-label", `Switch to ${nextTheme} theme`)
      this.buttonTarget.setAttribute("title", `Switch to ${nextTheme} theme`)
    }
  }
}
