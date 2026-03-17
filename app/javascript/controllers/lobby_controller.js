import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player1", "player2", "greeting", "matchList", "dropdown1", "dropdown2"]

  connect() {
    const p1 = localStorage.getItem("dartz_player1")
    const p2 = localStorage.getItem("dartz_player2")

    if (p1) this.player1Target.value = p1
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
clearMatches() {
  localStorage.removeItem("dartz_matches")
  if (this.hasMatchListTarget) this.matchListTarget.innerHTML = `
    <div class="text-center py-20 border border-dashed border-zinc-800 rounded-lg">
      <p class="text-zinc-600 text-sm">No matches yet.</p>
      <p class="text-zinc-700 text-xs mt-1">Create one to get started.</p>
    </div>`
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
        <div class="text-center py-20 border border-dashed border-zinc-800 rounded-lg">
          <p class="text-zinc-600 text-sm">No matches yet.</p>
          <p class="text-zinc-700 text-xs mt-1">Create one to get started.</p>
        </div>`
      return
    }

    this.matchListTarget.innerHTML = stored.map(() => `
      <div class="match-card rounded-lg p-4 opacity-40 animate-pulse">
        <div class="h-4 w-20 bg-zinc-800 rounded"></div>
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
        const pct        = Math.max((501 - p.score) * 100 / 501, 0)
        const nameColor  = p.winner ? "#4ade80" : "#555"
        const scoreColor = p.winner ? "#4ade80" : "#3a3a3a"
        const barColor   = p.winner ? "#16a34a" : "#2a2a2a"
        const avgColor   = p.avg >= 60 ? "#22c55e" : p.avg >= 40 ? "#f59e0b" : "#3a3a3a"
        const avgHtml    = p.avg > 0
          ? `<span style="font-family:'DM Mono',monospace;font-size:0.6rem;color:${avgColor};
                          min-width:38px;text-align:right;margin-left:4px">avg ${p.avg}</span>`
          : ""

        return `
          <div style="margin-bottom:4px">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
              <span style="font-family:'DM Mono',monospace;font-size:0.7rem;color:${nameColor};
                           white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:1">
                ${p.name}
              </span>
              <span style="font-family:'Bebas Neue',sans-serif;font-size:1.1rem;color:${scoreColor};
                           min-width:32px;text-align:right">
                ${p.score}
              </span>
              ${avgHtml}
            </div>
            <div style="height:2px;background:#1e1e1e;border-radius:2px;margin-top:2px;overflow:hidden">
              <div style="height:100%;width:${pct}%;background:${barColor};border-radius:2px"></div>
            </div>
          </div>`
      }).join("")

      const badge = data.finished
        ? `<span style="font-family:'DM Mono',monospace;font-size:0.65rem;color:#f87171;
                        border:1px solid #7f1d1d;background:#450a0a;padding:2px 6px;border-radius:4px">FINISHED</span>`
        : `<span style="font-family:'DM Mono',monospace;font-size:0.65rem;color:#4ade80;
                        border:1px solid #14532d;background:#052e16;padding:2px 6px;border-radius:4px">LIVE</span>`

      return `
        <a href="/matches/${data.id}" class="match-card rounded-lg p-4" style="display:block;text-decoration:none">
          <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:16px">
            <div style="flex-shrink:0">
              <p style="font-family:'Bebas Neue',sans-serif;color:#555;font-size:1rem;letter-spacing:0.05em">
                Match #${data.id}
              </p>
              <p style="font-family:'DM Mono',monospace;font-size:0.65rem;color:#3a3a3a">${date}</p>
            </div>
            <div style="flex:1;min-width:0">${playerRows}</div>
            <div style="flex-shrink:0;display:flex;flex-direction:column;align-items:flex-end;gap:4px">
              ${badge}
              <span style="font-family:'DM Mono',monospace;font-size:0.7rem;color:#dc2626">OPEN →</span>
            </div>
          </div>
        </a>`
    }).join("")

    this.matchListTarget.innerHTML = cards || `
      <div class="text-center py-20 border border-dashed border-zinc-800 rounded-lg">
        <p class="text-zinc-600 text-sm">No matches found.</p>
      </div>`
  }
}
