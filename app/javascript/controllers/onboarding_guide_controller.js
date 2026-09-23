import { Controller } from "@hotwired/stimulus"

const VERSION = 1

export default class extends Controller {
  static targets = ["dialog", "card", "title", "body", "progress", "back", "next", "link", "dontShow", "highlight", "reopen"]
  static values = { version: Number, account: Boolean, audience: String, savedVersion: Number, saveUrl: String, openLabel: String, nextLabel: String, finishLabel: String, homeUrl: String, setupMode: Boolean, continueMode: Boolean, returnMode: Boolean }

  connect() {
    this.steps = this.translatedSteps()
    this.index = 0
    this.setupMode = this.setupModeValue
    if (this.setupMode) {
      try {
        this.steps = JSON.parse(this.element.dataset.setupSteps)
        if (!Array.isArray(this.steps) || this.steps.length === 0) throw new Error("Empty setup tour")
      } catch (error) {
        console.error("Unable to load match setup tour; falling back to the app tour.", error)
        this.setupMode = false
        this.steps = this.translatedSteps()
      }
    }
    else if (this.continueModeValue) this.index = 2
    else if (this.returnModeValue) this.index = 1
    this.onKeydown = (event) => {
      if (event.key === "Escape" && !this.dialogTarget.hidden) this.close()
    }
    this.onLocaleSubmit = (event) => {
      if (event.target.matches('form[action="/locale"]')) this.sessionDismiss()
    }
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("submit", this.onLocaleSubmit, true)
    if (this.setupMode || this.continueModeValue || this.returnModeValue) this.open(this.index)
    else if (this.shouldShow()) this.open()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("submit", this.onLocaleSubmit, true)
    this.clearHighlight()
  }

  shouldShow() {
    if (sessionStorage.getItem(this.sessionKey)) return false
    if (this.accountValue) return this.savedVersionValue < this.versionValue
    return Number(localStorage.getItem("dartz_onboarding_version") || 0) < this.versionValue
  }

  open(index = 0) {
    this.index = index
    this.dialogTarget.hidden = false
    this.reopenTarget.hidden = true
    this.renderStep()
    this.cardTarget.focus()
  }

  close() {
    if (this.dontShowTarget.checked) this.saveCompletion()
    else this.sessionDismiss()
    this.dialogTarget.hidden = true
    this.reopenTarget.hidden = false
    this.clearHighlight()
  }

  next() {
    if (this.index >= this.steps.length - 1) {
      if (this.setupMode) {
        window.location.assign(`${this.homeUrlValue}?onboarding=continue`)
        return
      }
      this.saveCompletion()
      this.dialogTarget.hidden = true
      this.reopenTarget.hidden = false
      this.clearHighlight()
      return
    }
    this.index += 1
    this.renderStep()
  }

  back() {
    if (this.setupMode && this.index === 0) {
      window.location.assign(`${this.homeUrlValue}?onboarding=return`)
      return
    }
    if (this.index > 0) {
      this.index -= 1
      this.renderStep()
      return
    }
    this.close()
  }

  renderStep() {
    const step = this.steps[this.index]
    if (!step) {
      this.index = 0
      this.setupMode = false
      this.steps = this.translatedSteps()
      return this.renderStep()
    }
    this.titleTarget.textContent = step.title
    this.bodyTarget.textContent = step.body
    this.progressTarget.textContent = `${this.index + 1} / ${this.steps.length}`
    this.nextTarget.textContent = this.index === this.steps.length - 1
      ? (step.finish || this.finishLabelValue)
      : (step.next || this.nextLabelValue)
    this.linkTarget.hidden = !step.href
    if (step.href) {
      this.linkTarget.href = step.href
      this.linkTarget.textContent = step.link
      this.linkTarget.target = step.new_tab ? "_blank" : "_self"
      this.linkTarget.rel = step.new_tab ? "noopener" : ""
    }
    this.highlightTarget.textContent = step.tip
    this.highlightTarget.hidden = !step.tip
    this.clearHighlight()
    let target = null
    try {
      target = step.selector && document.querySelector(step.selector)
    } catch (error) {
      console.warn("Invalid onboarding highlight selector:", step.selector, error)
    }
    if (target) {
      target.classList.add("onboarding-target-highlight")
      this.highlighted = target
    }
  }

  get sessionKey() {
    return `dartz_onboarding_dismissed_${this.audienceValue}_v${this.versionValue}`
  }

  sessionDismiss() {
    sessionStorage.setItem(this.sessionKey, "1")
  }

  saveCompletion() {
    if (this.accountValue) {
      fetch(this.saveUrlValue, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify({ onboarding_guide: { version: this.versionValue } })
      }).catch(() => {})
      this.savedVersionValue = this.versionValue
    } else {
      localStorage.setItem("dartz_onboarding_version", String(this.versionValue))
    }
  }

  clearHighlight() {
    this.highlighted?.classList.remove("onboarding-target-highlight")
    this.highlighted = null
  }

  translatedSteps() {
    const copy = JSON.parse(this.element.dataset.steps)
    return copy.map((step) => ({ ...step, href: step.href || null }))
  }
}
