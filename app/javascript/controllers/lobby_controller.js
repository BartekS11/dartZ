import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player1", "player2", "greeting", "matchList", "dropdown1", "dropdown2"]
  static values = { signedIn: Boolean, currentUserName: String }

  connect() {
    const p1 = localStorage.getItem("dartz_player1")
    const p2 = localStorage.getItem("dartz_player2")

    if (this.signedInValue && this.currentUserNameValue) {
      this.player1Target.value = this.currentUserNameValue
    } else if (p1) {
      this.player1Target.value = p1
    }

    if (p2) this.player2Target.value = p2

    this.renderDropdowns()
    this.updateGreeting()
    this.renderMatchList()
  }

  // ── Player storage ──────────────────────────────────────────────────────────

  getSavedPlayers() {
    return JSON.parse(localStorage.getItem("dartz_players") || "[]")
  }

  savePlayer(name) {
    if (!name.trim()) return
    const players = this.getSavedPlayers()
    if (!players.includes(name.trim())) {
      players.unshift(name.trim())
      localStorage.setItem("dartz_players", JSON.stringify(players.slice(0, 20)))
    }
  }

  removePlayer(name) {
    const players = this.getSavedPlayers().filter(p => p !== name)
    localStorage.setItem("dartz_players", JSON.stringify(players))
    this.renderDropdowns()
  }

  // ── Dropdowns ───────────────────────────────────────────────────────────────

  renderDropdowns() {
    if (this.hasDropdown1Target) this.renderDropdown(this.dropdown1Target, 1)
    if (this.hasDropdown2Target) this.renderDropdown(this.dropdown2Target, 2)
  }

  renderDropdown(el, slot) {
    const players = this.getSavedPlayers()

    if (players.length === 0) {
      el.innerHTML = `
        <div style="font-family:'DM Mono',monospace;font-size:0.65rem;color:#333;
                    padding:10px 12px;text-align:center;letter-spacing:0.1em">
          NO SAVED PLAYERS
        </div>`
      return
    }

    el.innerHTML = players.map(name => `
      <div class="dropdown-item"
           style="display:flex;align-items:center;justify-content:space-between;
                  padding:8px 12px;cursor:pointer;transition:background 0.1s ease;"
           onmouseover="this.style.background='#1a1a1a'"
           onmouseout="this.style.background='transparent'"
           data-action="click->lobby#selectPlayer"
           data-slot="${slot}"
           data-name="${name}">
        <span style="font-family:'DM Mono',monospace;font-size:0.75rem;color:#ccc;
                     letter-spacing:0.05em">${name}</span>
        <button type="button"
                style="font-family:'DM Mono',monospace;font-size:0.6rem;color:#444;
                       background:none;border:none;cursor:pointer;padding:2px 4px;
                       transition:color 0.1s ease"
                onmouseover="this.style.color='#dc2626';event.stopPropagation()"
                onmouseout="this.style.color='#444'"
                data-action="click->lobby#removePlayer"
                data-name="${name}">
          ✕
        </button>
      </div>
    `).join("")
  }

  selectPlayer(e) {
    const name = e.currentTarget.dataset.name
    const slot = e.currentTarget.dataset.slot

    if (slot === "1") {
      this.player1Target.value = name
      this.closeDropdown(this.dropdown1Target)
    } else {
      this.player2Target.value = name
      this.closeDropdown(this.dropdown2Target)
    }

    this.save()
  }

  removePlayer(e) {
    e.stopPropagation()
    const name = e.currentTarget.dataset.name
    this.removePlayer(name)
  }

  toggleDropdown1() {
    this.toggleDropdown(this.dropdown1Target)
  }

  toggleDropdown2() {
    this.toggleDropdown(this.dropdown2Target)
  }

  toggleDropdown(el) {
    const isOpen = el.style.display === "block"
    // Close all dropdowns first
    if (this.hasDropdown1Target) this.closeDropdown(this.dropdown1Target)
    if (this.hasDropdown2Target) this.closeDropdown(this.dropdown2Target)

    if (!isOpen) {
      this.renderDropdown(el, el === this.dropdown1Target ? 1 : 2)
      el.style.display = "block"
    }
  }

  closeDropdown(el) {
    el.style.display = "none"
  }

  // Close dropdowns when clicking outside
  clickOutside(e) {
    const isInsideForm = this.element.contains(e.target)
    if (!isInsideForm) {
      if (this.hasDropdown1Target) this.closeDropdown(this.dropdown1Target)
      if (this.hasDropdown2Target) this.closeDropdown(this.dropdown2Target)
    }
  }

  // ── Save / submit ────────────────────────────────────────────────────────────

  save() {
    const p1 = this.player1Target.value
    const p2 = this.player2Target.value
    localStorage.setItem("dartz_player1", p1)
    localStorage.setItem("dartz_player2", p2)
    this.updateGreeting()
  }

  // Called on form submit — persist both names to saved players list
  savePlayers() {
    this.save()
    this.savePlayer(this.player1Target.value)
    this.savePlayer(this.player2Target.value)
  }

  // ── Greeting ────────────────────────────────────────────────────────────────

  updateGreeting() {
    const p1      = this.player1Target.value.trim()
    const p2      = this.player2Target.value.trim()
    const wrapper = document.getElementById("greeting-wrapper")
    if (!wrapper) return

    if (p1 && p2) {
      if (this.hasGreetingTarget) {
        this.greetingTarget.textContent = `${p1}  ·  vs  ·  ${p2}`
      }
      wrapper.classList.remove("hidden")
    } else {
      wrapper.classList.add("hidden")
    }
  }

  // ── Match list ───────────────────────────────────────────────────────────────

  static saveMatch(id, player1, player2) {
    const matches = JSON.parse(localStorage.getItem("dartz_matches") || "[]")
    const exists  = matches.find(m => m.id === id)
    if (!exists) {
      matches.unshift({ id, player1, player2, createdAt: new Date().toISOString() })
      localStorage.setItem("dartz_matches", JSON.stringify(matches.slice(0, 20)))
    }
  }
async clearMatches() {
  localStorage.removeItem("dartz_matches")

  if (this.signedInValue) {
    const response = await fetch("/matches/clear", {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        "Accept": "text/html"
      }
    })

    if (response.ok) {
      window.location.reload()
      return
    }
  }

  if (this.hasMatchListTarget) this.matchListTarget.innerHTML = `
    <div class="theme-card p-4 text-center">
      <p class="text-muted-theme mb-1">No matches yet.</p>
      <p class="text-subtle-theme small mb-0">Create one to get started.</p>
    </div>`
}
swapPlayers() {
  const p1 = this.player1Target.value
  const p2 = this.player2Target.value

  this.player1Target.value = p2
  this.player2Target.value = p1

  this.save()
}
clearPlayers() {
  localStorage.removeItem("dartz_players")
  localStorage.removeItem("dartz_player1")
  localStorage.removeItem("dartz_player2")

  if (this.hasPlayer1Target) this.player1Target.value = ""
  if (this.hasPlayer2Target) this.player2Target.value = ""

  const wrapper = document.getElementById("greeting-wrapper")
  if (wrapper) wrapper.classList.add("hidden")

  this.renderDropdowns()
}
  async renderMatchList() {
    if (!this.hasMatchListTarget) return

    const stored = JSON.parse(localStorage.getItem("dartz_matches") || "[]")

    if (stored.length === 0) {
      this.matchListTarget.innerHTML = `
        <div class="theme-card p-4 text-center">
          <p class="text-muted-theme mb-1">No matches yet.</p>
          <p class="text-subtle-theme small mb-0">Create one to get started.</p>
        </div>`
      return
    }

    this.matchListTarget.innerHTML = stored.map(() => `
      <div class="theme-match-card p-4 opacity-50">
        <div class="placeholder-glow"><span class="placeholder col-4"></span></div>
      </div>
    `).join("")

    const results = await Promise.all(
      stored.map(m =>
        fetch(`/matches/${m.id}/summary`)
          .then(r => r.json())
           .catch(err => { console.error(`Failed match ${m.id}:`, err); return null })
      )
    )

    const cards = results.map((data, i) => {
      if (!data) return ""

      const date = new Date(stored[i].createdAt).toLocaleDateString("en-GB", {
        day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
      })

      const playerRows = data.players.map(p => {
        const pct = Math.max((501 - p.score) * 100 / 501, 0)
        const avgHtml = p.avg > 0 ? `<span class="avg mono">avg ${p.avg}</span>` : ""

        return `
          <div>
            <div class="player-line">
              <span class="name mono ${p.winner ? "is-winner" : ""}">${p.name}</span>
              <span class="value bebas ${p.winner ? "is-winner" : ""}">${p.score}</span>
              ${avgHtml}
            </div>
            <div class="progress-thin"><span style="width:${pct}%;background:${p.winner ? "var(--theme-success)" : "var(--theme-border-strong)"}"></span></div>
          </div>`
      }).join("")

      const identifier = data.ui_identifier || data.match_identifier || `#${data.id}`

      const badge = data.finished
        ? `<span class="theme-chip mono is-finished">Finished</span>`
        : `<span class="theme-chip mono is-live">Live</span>`

      return `
        <a href="/matches/${data.id}" class="theme-match-card p-3 p-md-4">
          <div class="row align-items-start g-3 position-relative">
            <div class="col-12 col-sm-4">
              <div class="match-identifier bebas">Match ${identifier}</div>
              <div class="mono text-subtle-theme small mb-2">${date}</div>
            </div>
            <div class="col-12 col-sm-5">${playerRows}</div>
            <div class="col-12 col-sm-3 text-sm-end">
              ${badge}
              <div class="mt-3 mono text-primary-theme small">Open →</div>
            </div>
          </div>
        </a>`
    }).join("")

    this.matchListTarget.innerHTML = cards || `
      <div class="theme-card p-4 text-center">
        <p class="text-muted-theme mb-0">No matches found.</p>
      </div>`
  }
}
