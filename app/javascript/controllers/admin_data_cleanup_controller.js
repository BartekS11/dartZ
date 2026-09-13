import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "firstStep", "secondStep", "email", "reason", "acknowledgement"]
  static values = { email: String }

  open(event) {
    event.preventDefault()
    this.firstStepTarget.hidden = false
    this.secondStepTarget.hidden = true
    this.emailTarget.value = ""
    this.reasonTarget.value = ""
    this.emailTarget.setCustomValidity("")
    this.reasonTarget.setCustomValidity("")
    this.acknowledgementTarget.value = ""
    this.dialogTarget.showModal()
    this.emailTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  continue(event) {
    event.preventDefault()
    const emailMatches = this.emailTarget.value === this.emailValue
    this.emailTarget.setCustomValidity(emailMatches ? "" : `Enter ${this.emailValue} exactly.`)
    this.reasonTarget.setCustomValidity(this.reasonTarget.value.trim() ? "" : "Enter a reason.")
    if (!this.emailTarget.reportValidity() || !this.reasonTarget.reportValidity()) return

    this.firstStepTarget.hidden = true
    this.secondStepTarget.hidden = false
    this.acknowledgementTarget.value = "1"
  }

  back() {
    this.firstStepTarget.hidden = false
    this.secondStepTarget.hidden = true
    this.acknowledgementTarget.value = ""
  }
}
