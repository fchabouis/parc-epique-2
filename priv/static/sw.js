// Service worker of the installable app.
//
// LiveView needs a connection, so the site does not work offline. The worker
// only keeps the static files (stylesheet, script, icons, thumbnails) to open
// faster, and shows a page of its own when a page cannot be loaded because
// the network is down.
//
// Bump CACHE when this file or /offline.html changes.
const CACHE = "parc-epique-v1"
const OFFLINE_URL = "/offline.html"
const PRECACHE = [OFFLINE_URL, "/images/icons/icon-192.png", "/images/icons/icon-512.png"]

// Static files, refreshed in the background each time they are used.
const STATIC_PREFIXES = ["/assets/", "/images/", "/fonts/"]
// Photos never change once uploaded: take them from the cache first.
const PHOTO_PREFIX = "/uploads/photos/"

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(PRECACHE)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", event => {
  event.waitUntil(
    caches
      .keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", event => {
  const request = event.request
  if (request.method !== "GET") return

  const url = new URL(request.url)
  // Map tiles and any other site are left to the browser.
  if (url.origin !== self.location.origin) return

  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match(OFFLINE_URL)))
  } else if (url.pathname.startsWith(PHOTO_PREFIX)) {
    event.respondWith(cacheFirst(request))
  } else if (STATIC_PREFIXES.some(prefix => url.pathname.startsWith(prefix))) {
    event.respondWith(staleWhileRevalidate(request))
  }
})

async function cacheFirst(request) {
  const cached = await caches.match(request)
  return cached || fetchAndStore(request)
}

async function staleWhileRevalidate(request) {
  const cached = await caches.match(request)
  const update = fetchAndStore(request).catch(error => {
    if (cached) return cached
    throw error
  })
  return cached || update
}

async function fetchAndStore(request) {
  const response = await fetch(request)
  // Only complete, successful responses are kept (not partial or error ones).
  if (response.status === 200) {
    const cache = await caches.open(CACHE)
    await cache.put(request, response.clone())
  }
  return response
}
