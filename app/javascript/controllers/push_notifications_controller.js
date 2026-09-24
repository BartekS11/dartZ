import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "enable", "test"]
  static values = { publicKey: String, subscribeUrl: String, testUrl: String }

  connect() {
    this.refreshState()
  }

  async enable() {
    if (!this.supported()) return this.setStatus("unsupported")

    try {
      const permission = await Notification.requestPermission()
      if (permission !== "granted") return this.setStatus(permission === "denied" ? "denied" : "default")

      const registration = await navigator.serviceWorker.ready
      let subscription = await registration.pushManager.getSubscription()
      subscription ||= await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.decodePublicKey(this.publicKeyValue)
      })

      const payload = subscription.toJSON()
      payload.device_label = this.deviceLabel()
      await this.request(this.subscribeUrlValue, { method: "POST", body: JSON.stringify({ subscription: payload }) })
      this.setStatus("enabled")
      window.location.reload()
    } catch (error) {
      console.error("Push subscription failed", error)
      this.setStatus("failed")
    }
  }

  async test() {
    try {
      await this.request(this.testUrlValue, { method: "POST", body: "{}" })
      this.setStatus("testQueued")
    } catch (error) {
      console.error("Push test failed", error)
      this.setStatus("failed")
    }
  }

  async refreshState() {
    if (!this.supported()) return this.setStatus("unsupported")
    if (Notification.permission === "denied") return this.setStatus("denied")

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()
    this.setStatus(subscription ? "enabled" : Notification.permission)
  }

  supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window && this.publicKeyValue.length > 0
  }

  async request(url, options) {
    const response = await fetch(url, {
      ...options,
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      }
    })
    if (!response.ok) throw new Error(`Request failed: ${response.status}`)
    return response
  }

  decodePublicKey(value) {
    const padding = "=".repeat((4 - value.length % 4) % 4)
    const raw = atob((value + padding).replace(/-/g, "+").replace(/_/g, "/"))
    return Uint8Array.from([...raw].map(character => character.charCodeAt(0)))
  }

  deviceLabel() {
    const platform = navigator.userAgentData?.platform || navigator.platform || "Browser"
    return `${platform} browser`.slice(0, 80)
  }

  setStatus(key) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = this.statusTarget.dataset[key] || key
    this.enableTarget.disabled = key === "enabled" || key === "unsupported" || key === "denied"
    if (this.hasTestTarget) this.testTarget.disabled = key !== "enabled" && key !== "testQueued"
  }
}
