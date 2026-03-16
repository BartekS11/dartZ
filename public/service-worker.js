importScripts('https://storage.googleapis.com/workbox-cdn/releases/7.0.0/workbox-sw.js')

const { registerRoute } = workbox.routing
const { NetworkFirst, CacheFirst } = workbox.strategies
const { BackgroundSyncPlugin } = workbox.backgroundSync
const { ExpirationPlugin } = workbox.expiration

registerRoute(
  ({ request }) => request.destination === 'document',
  new NetworkFirst({
    cacheName: 'dartz-pages',
    plugins: [
      new ExpirationPlugin({ maxEntries: 20, maxAgeSeconds: 60 * 60 })
    ]
  })
)

registerRoute(
  ({ request }) => ['script', 'style', 'font', 'image'].includes(request.destination),
  new CacheFirst({
    cacheName: 'dartz-assets',
    plugins: [
      new ExpirationPlugin({ maxEntries: 50, maxAgeSeconds: 60 * 60 * 24 * 7 })
    ]
  })
)

const throwQueue = new BackgroundSyncPlugin('throw-queue', {
  maxRetentionTime: 24 * 60 // 24 hours
})

registerRoute(
  ({ url }) => url.pathname.match(/\/turns\/\d+\/throws/),
  new NetworkFirst({ plugins: [throwQueue] }),
  'POST'
)

const undoQueue = new BackgroundSyncPlugin('undo-queue', {
  maxRetentionTime: 24 * 60
})

registerRoute(
  ({ url }) => url.pathname.match(/\/turns\/\d+\/throws\/last/),
  new NetworkFirst({ plugins: [undoQueue] }),
  'DELETE'
)
