import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player1", "player2", "greeting", "matchList"]

  connect() {
    const p1 = localStorage.getItem("dartz_player1")
    const p2 = localStorage.getItem("dartz_player2")

    if (p1) this.player1Target.value = p1
    if (p2) this.player2Target.value = p2

    this.updateGreeting()
    this.renderMatchList()
  }

  save() {
    localStorage.setItem("dartz_player1", this.player1Target.value)
    localStorage.setItem("dartz_player2", this.player2Target.value)
    this.updateGreeting()
  }

  // Call this from the match show page after match is created
  static saveMatch(id, player1, player2) {
    const matches = JSON.parse(localStorage.getItem("dartz_matches") || "[]")
    const exists = matches.find(m => m.id === id)
    if (!exists) {
      matches.unshift({ id, player1, player2, createdAt: new Date().toISOString() })
      localStorage.setItem("dartz_matches", JSON.stringify(matches.slice(0, 20)))
    }
  }

  renderMatchList() {
    if (!this.hasMatchListTarget) return

    const matches = JSON.parse(localStorage.getItem("dartz_matches") || "[]")
    if (matches.length === 0) {
      this.matchListTarget.innerHTML = `
        <div class="text-center py-20 border border-dashed border-zinc-800 rounded-lg">
          <p class="text-zinc-600 text-sm">No matches yet.</p>
          <p class="text-zinc-700 text-xs mt-1">Create one to get started.</p>
        </div>`
      return
    }

    this.matchListTarget.innerHTML = matches.map((match, i) => `
      <a href="/matches/${match.id}"
         class="match-card rounded-lg p-4 flex items-center justify-between block">
        <div class="flex items-center gap-4">
          <span class="text-zinc-600 mono text-xs w-6 text-right">${i + 1}</span>
          <div>
            <p class="match-id text-white text-xl">Match #${match.id}</p>
            <p class="text-zinc-500 text-xs mono">
              ${match.player1} vs ${match.player2}
              · ${new Date(match.createdAt).toLocaleDateString("en-GB", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
            </p>
          </div>
        </div>
        <span class="text-red-500 text-sm mono font-medium tracking-wider">OPEN →</span>
      </a>
    `).join("")
  }

  updateGreeting() {
    const p1 = this.player1Target.value.trim()
    const p2 = this.player2Target.value.trim()
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

  // Show skeleton while loading
  this.matchListTarget.innerHTML = stored.map(m => `
    <div class="match-card rounded-lg p-4 opacity-40 animate-pulse">
      <div class="flex items-center gap-4">
        <div class="h-4 w-20 bg-zinc-800 rounded"></div>
      </div>
    </div>
  `).join("")

  // Fetch live data for each match
  const results = await Promise.all(
    stored.map(m =>
      fetch(`/matches/${m.id}/summary`)
        .then(r => r.json())
        .catch(() => null)
    )
  )

  const cards = results.map((data, i) => {
    if (!data) return "" // failed fetch, skip

    const date = new Date(stored[i].createdAt).toLocaleDateString("en-GB", {
      day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
    })

const playerRows = data.players.map(p => {
  const pct = Math.max((501 - p.score) * 100 / 501, 0)
  const nameColor = p.winner ? "#4ade80" : "#555"
  const scoreColor = p.winner ? "#4ade80" : "#3a3a3a"
  const barColor = p.winner ? "#16a34a" : "#2a2a2a"

  return `
    <div style="margin-bottom:4px">
      <div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
        <span style="font-family:'DM Mono',monospace;font-size:0.7rem;color:${nameColor};
                     white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:1">
          ${p.name}
        </span>
        <span style="font-family:'Bebas Neue',sans-serif;font-size:1.1rem;color:${scoreColor};
                     min-width:36px;text-align:right">
          ${p.score}
        </span>
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
          <div style="min-width:0">
            <p style="font-family:'Bebas Neue',sans-serif;color:#555;font-size:1rem;letter-spacing:0.05em">
              Match #${data.id}
            </p>
            <p style="font-family:'DM Mono',monospace;font-size:0.65rem;color:#3a3a3a">${date}</p>
          </div>
          <div style="flex-shrink:0;min-width:150px">${playerRows}</div>
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