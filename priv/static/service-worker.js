// Replaces the service worker of the old site (Vue app with Firebase), which
// was registered under this very URL and keeps serving the old app from its
// cache. Browsers fetch this file again to update it: this version deletes
// every cache, unregisters itself and reloads the open pages, which then load
// the new site (and its own worker, /sw.js).
self.addEventListener("install", () => self.skipWaiting())

self.addEventListener("activate", event => {
  event.waitUntil(
    caches
      .keys()
      .then(keys => Promise.all(keys.map(key => caches.delete(key))))
      .then(() => self.registration.unregister())
      .then(() => self.clients.matchAll({type: "window"}))
      .then(clients => clients.forEach(client => client.navigate(client.url)))
  )
})
