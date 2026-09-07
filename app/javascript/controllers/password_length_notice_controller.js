import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message"]

  warnIfPasteTooLong(event) {
    const maxLength = this.inputTarget.maxLength
    if (maxLength < 0) return

    const pastedText = event.clipboardData?.getData("text") || ""
    if (!pastedText) return

    const selectionStart = this.inputTarget.selectionStart || 0
    const selectionEnd = this.inputTarget.selectionEnd || 0
    const selectedLength = Math.max(selectionEnd - selectionStart, 0)
    const resultingLength = this.inputTarget.value.length - selectedLength + pastedText.length

    if (resultingLength > maxLength) {
      this.showMessage()
    } else {
      this.hideMessage()
    }
  }

  hideWhenBelowLimit() {
    if (this.inputTarget.value.length < this.inputTarget.maxLength) {
      this.hideMessage()
    }
  }

  showMessage() {
    this.messageTarget.classList.remove("is-hidden")
  }

  hideMessage() {
    this.messageTarget.classList.add("is-hidden")
  }
}
