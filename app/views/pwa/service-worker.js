self.addEventListener("push", event => {
  event.waitUntil((async () => {
    let payload
    try {
      payload = event.data?.json()
    } catch (_error) {
      return
    }

    if (!payload || typeof payload.title !== "string" || typeof payload.options !== "object") return

    const path = safePath(payload.options?.data?.path)
    const options = {
      body: String(payload.options.body || ""),
      tag: String(payload.options.tag || "dartz-notification"),
      renotify: Boolean(payload.options.renotify),
      data: { path },
      icon: "/icon.png",
      badge: "/icon.png"
    }
    await self.registration.showNotification(payload.title, options)
  })())
})

self.addEventListener("notificationclick", event => {
  event.notification.close()
  const path = safePath(event.notification.data?.path)

  event.waitUntil((async () => {
    const windows = await clients.matchAll({ type: "window", includeUncontrolled: true })
    const targetUrl = new URL(path, self.location.origin).href
    for (const client of windows) {
      if (new URL(client.url).href === targetUrl && "focus" in client) return client.focus()
    }

    const sameOriginClient = windows.find(client => new URL(client.url).origin === self.location.origin)
    if (sameOriginClient && "navigate" in sameOriginClient && "focus" in sameOriginClient) {
      await sameOriginClient.navigate(targetUrl)
      return sameOriginClient.focus()
    }
    if (clients.openWindow) return clients.openWindow(targetUrl)
  })())
})

function safePath(value) {
  if (typeof value !== "string" || !value.startsWith("/") || value.startsWith("//") || value.includes("\\")) return "/"
  try {
    const url = new URL(value, self.location.origin)
    return url.origin === self.location.origin ? `${url.pathname}${url.search}${url.hash}` : "/"
  } catch (_error) {
    return "/"
  }
}
