// The old site (Vue router in hash mode) had three URLs: /#/, /#/apropos and
// /#/login. A hash never reaches the server, so they are redirected here.

// The path that replaces a hash of the old site, or null when there is none
export function legacyPath(hash, locale) {
  const route = hash.replace(/^#\/?/, "").split("?")[0].replace(/\/+$/, "")

  switch (route) {
    case "apropos":
      return `/${locale}/a-propos`
    case "login":
      return "/users/log-in"
    default:
      return null
  }
}

export function redirectLegacyUrl() {
  if (!location.hash.startsWith("#/")) return

  const path = legacyPath(location.hash, document.documentElement.lang || "fr")

  if (path) {
    location.replace(path)
  } else {
    // "/#/": the map itself
    history.replaceState(null, "", location.pathname + location.search)
  }
}
