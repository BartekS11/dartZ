import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pad", "input", "padButton", "inputButton"]
  static values = { remoteInvite: Boolean, myPlayerId: Number, myPlayerPublicId: String }

  connect() {
    this.show(this.defaultView())
    this.element.addEventListener("submit", this.attachActorPlayerId, true)
    this.boundSyncTurnLock = () => window.requestAnimationFrame(() => {
      this.syncTurnLock()
      this.syncFinishPopup()
    })
    document.addEventListener("turbo:before-stream-render", this.boundSyncTurnLock)
    document.addEventListener("turbo:render", this.boundSyncTurnLock)
    this.turnLockObserver = new MutationObserver(this.boundSyncTurnLock)
    this.turnLockObserver.observe(this.element, { childList: true, subtree: true })
    this.syncTurnLock()
    this.syncFinishPopup()
  }

  disconnect() {
    this.element.removeEventListener("submit", this.attachActorPlayerId, true)
    document.removeEventListener("turbo:before-stream-render", this.boundSyncTurnLock)
    document.removeEventListener("turbo:render", this.boundSyncTurnLock)
    this.turnLockObserver?.disconnect()
  }

  showPad() {
    this.show("pad")
  }

  showInput() {
    this.show("input")
  }

  defaultView() {
    return "all"
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

  attachActorPlayerId = (event) => {
    const actorPlayerId = this.myPlayerPublicIdValue
    if (!actorPlayerId) return

    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    if (!form.closest("#keyboard-section")) return

    let input = form.querySelector('input[name="actor_player_id"]')
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "actor_player_id"
      form.appendChild(input)
    }
    input.value = actorPlayerId
  }

  syncTurnLock() {
    if (!this.remoteInviteValue || !this.myPlayerIdValue) return

    const currentPanel = this.element.querySelector("[data-keyboard-player-id-value]")
    if (!currentPanel) return

    const currentPlayerId = Number(currentPanel.dataset.keyboardPlayerIdValue)
    const locked = currentPlayerId !== this.myPlayerIdValue

    this.element.classList.toggle("is-waiting-for-opponent", locked)

    const controls = this.element.querySelectorAll("#keyboard-section input, #keyboard-section button")
    controls.forEach((control) => {
      if (control.closest(".bot-turn-disabled")) return
      if (control.classList.contains("turn-skip-button")) return
      control.disabled = locked
    })

    this.renderTurnLockMessage(locked)
  }

  syncFinishPopup() {
    if (!this.remoteInviteValue || !this.myPlayerIdValue) return

    const popup = document.getElementById("finish-popup-overlay")
    if (!popup) return

    const winnerPlayerId = Number(popup.dataset.winnerPlayerId || 0)
    if (winnerPlayerId && winnerPlayerId !== this.myPlayerIdValue) {
      popup.remove()
    }
  }

  renderTurnLockMessage(locked) {
    const panel = this.element.querySelector(".match-input-head")
    if (!panel) return

    let message = this.element.querySelector("[data-turn-lock-message]")
    if (!locked) {
      message?.remove()
      return
    }

    if (!message) {
      message = document.createElement("div")
      message.dataset.turnLockMessage = "true"
      message.className = "mono mt-2 text-xs uppercase tracking-[0.14em]"
      message.style.color = "var(--theme-muted)"
      panel.appendChild(message)
    }

    message.textContent = "Waiting for the other player — input locked"
  }
}
