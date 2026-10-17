import L from "../../vendor/leaflet-global.js"
import "../../vendor/leaflet.markercluster/leaflet.markercluster-src.js"

const DEFAULT_VIEW = {lat: 48.85, lng: 2.34, zoom: 13}
const VIEW_KEY = "parc-epique:view"
const TILES_KEY = "parc-epique:tiles"
const OSM_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'

const TILES = {
  "OpenStreetMap": {
    url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    attribution: OSM_ATTRIBUTION,
    maxZoom: 19,
  },
  "OSM France": {
    url: "https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png",
    attribution: `${OSM_ATTRIBUTION}, tuiles OSM France`,
    maxZoom: 20,
  },
  "Humanitarian": {
    url: "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
    attribution: `${OSM_ATTRIBUTION}, tuiles Humanitarian OSM Team`,
    maxZoom: 20,
  },
}

const storage = {
  get(key) {
    try { return JSON.parse(localStorage.getItem(key)) } catch (_e) { return null }
  },
  set(key, value) {
    try { localStorage.setItem(key, JSON.stringify(value)) } catch (_e) { /* private mode */ }
  },
}

const icon = (reviewed) =>
  L.divIcon({
    className: reviewed ? "pe-marker pe-marker--reviewed" : "pe-marker",
    iconSize: reviewed ? [20, 20] : [14, 14],
  })

// Map of playgrounds: sends the visible bounds to the LiveView ("bounds") and
// draws the playgrounds it pushes back ("playgrounds").
export const MapHook = {
  mounted() {
    const saved = storage.get(VIEW_KEY)
    const view = saved && Number.isFinite(saved.lat) && Number.isFinite(saved.lng) ? saved : DEFAULT_VIEW

    this.map = L.map(this.el).setView([view.lat, view.lng], view.zoom || DEFAULT_VIEW.zoom)
    this.addTiles()
    this.addLocateControl()

    this.cluster = L.markerClusterGroup({showCoverageOnHover: false, maxClusterRadius: 45, disableClusteringAtZoom: 16})
    this.map.addLayer(this.cluster)
    this.markers = new Map()

    this.map.on("moveend", () => {
      const center = this.map.getCenter()
      storage.set(VIEW_KEY, {lat: center.lat, lng: center.lng, zoom: this.map.getZoom()})
      this.pushBounds()
    })

    this.handleEvent("playgrounds", ({playgrounds}) => this.draw(playgrounds))
    this.pushBounds()

    if (!saved) this.locate({fly: true})
  },

  destroyed() {
    if (this.map) this.map.remove()
  },

  addTiles() {
    const layers = {}
    for (const [name, {url, attribution, maxZoom}] of Object.entries(TILES)) {
      layers[name] = L.tileLayer(url, {attribution, maxZoom})
    }
    const savedName = storage.get(TILES_KEY)
    ;(layers[savedName] || layers["OpenStreetMap"]).addTo(this.map)
    L.control.layers(layers, null, {position: "topright"}).addTo(this.map)
    this.map.on("baselayerchange", (e) => storage.set(TILES_KEY, e.name))
  },

  addLocateControl() {
    const hook = this
    const Locate = L.Control.extend({
      options: {position: "topleft"},
      onAdd() {
        const button = L.DomUtil.create("button", "leaflet-bar pe-locate")
        button.type = "button"
        button.title = hook.el.dataset.locateLabel
        button.setAttribute("aria-label", hook.el.dataset.locateLabel)
        button.textContent = "◎"
        L.DomEvent.disableClickPropagation(button)
        L.DomEvent.on(button, "click", () => hook.locate({fly: true}))
        return button
      },
    })
    this.map.addControl(new Locate())
  },

  locate({fly}) {
    if (!navigator.geolocation) return

    navigator.geolocation.getCurrentPosition(
      ({coords}) => {
        const latlng = [coords.latitude, coords.longitude]
        if (this.position) {
          this.position.setLatLng(latlng)
          this.accuracy.setLatLng(latlng).setRadius(coords.accuracy)
        } else {
          this.accuracy = L.circle(latlng, {radius: coords.accuracy, stroke: false, fillOpacity: 0.08}).addTo(this.map)
          this.position = L.circleMarker(latlng, {radius: 6, stroke: false, fillColor: "#2563eb", fillOpacity: 0.9}).addTo(this.map)
        }
        if (fly) this.map.flyTo(latlng, Math.max(this.map.getZoom(), 15))
      },
      () => {},
      {enableHighAccuracy: true, timeout: 10000},
    )
  },

  pushBounds() {
    const bounds = this.map.getBounds()
    this.pushEvent("bounds", {
      south: bounds.getSouth(),
      west: bounds.getWest(),
      north: bounds.getNorth(),
      east: bounds.getEast(),
    })
  },

  draw(playgrounds) {
    const added = []
    for (const {id, lat, lng, name, reviewed} of playgrounds) {
      if (this.markers.has(id)) continue
      const marker = L.marker([lat, lng], {icon: icon(reviewed), zIndexOffset: reviewed ? 100 : 0, title: name})
      marker.bindPopup(`<strong>${escapeHtml(name)}</strong>`)
      this.markers.set(id, marker)
      added.push(marker)
    }
    this.cluster.addLayers(added)
  },
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}
