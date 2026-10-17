import maplibregl from "../../vendor/maplibre-gl/maplibre-gl.js"
import {Protocol} from "../../vendor/pmtiles/pmtiles.js"

// The tiles of tuiles.enliberte.fr are a single PMTiles archive (pmtiles:// URLs).
maplibregl.addProtocol("pmtiles", new Protocol().tile)

const DEFAULT_VIEW = {lat: 48.85, lng: 2.34, zoom: 13}
const FOCUS_ZOOM = 17
const VIEW_KEY = "parc-epique:view"

const COLOR = "#b6c4bd"
const REVIEWED_COLOR = "#1bd980"
const CLUSTER_COLOR = "#0f9d58"

const storage = {
  get(key) {
    try { return JSON.parse(localStorage.getItem(key)) } catch (_e) { return null }
  },
  set(key, value) {
    try { localStorage.setItem(key, JSON.stringify(value)) } catch (_e) { /* private mode */ }
  },
}

const savedView = () => {
  const saved = storage.get(VIEW_KEY)
  return saved && Number.isFinite(saved.lat) && Number.isFinite(saved.lng) ? saved : null
}

// Map of playgrounds (MapLibre GL): sends the visible bounds to the LiveView
// ("bounds") and draws the playgrounds it pushes back ("playgrounds") as a
// clustered GeoJSON source. A click on a playground opens its sheet ("open");
// when a playground opens, "focus" brings it into view.
export const MapHook = {
  mounted() {
    const saved = savedView()
    const focus = {lat: parseFloat(this.el.dataset.focusLat), lng: parseFloat(this.el.dataset.focusLng)}
    const focused = Number.isFinite(focus.lat) && Number.isFinite(focus.lng)
    const view = focused ? {...focus, zoom: FOCUS_ZOOM} : saved || DEFAULT_VIEW

    this.features = new Map()
    this.map = new maplibregl.Map({
      container: this.el,
      style: this.el.dataset.styleUrl,
      center: [view.lng, view.lat],
      zoom: view.zoom || DEFAULT_VIEW.zoom,
      attributionControl: {compact: true},
      locale: {
        "GeolocateControl.FindMyLocation": this.el.dataset.locateLabel,
        "GeolocateControl.LocationNotAvailable": this.el.dataset.locateLabel,
      },
    })
    this.map.addControl(new maplibregl.NavigationControl({showCompass: false}), "top-left")

    this.geolocate = new maplibregl.GeolocateControl({
      positionOptions: {enableHighAccuracy: true},
      trackUserLocation: false,
      fitBoundsOptions: {maxZoom: 15},
    })
    this.map.addControl(this.geolocate, "top-left")

    this.map.on("load", () => {
      this.addPlaygroundLayers()
      this.handleEvent("playgrounds", ({playgrounds}) => this.draw(playgrounds))
      this.pushBounds()
      if (!saved && !focused) this.geolocate.trigger()
      this.listenForNewPlaygrounds()
    })

    this.handleEvent("reviewed", ({id}) => {
      const feature = this.features.get(id)
      if (feature && !feature.properties.reviewed) {
        feature.properties.reviewed = true
        this.refresh()
      }
    })

    this.handleEvent("focus", ({lat, lng}) => {
      if (!this.map.getBounds().contains([lng, lat])) {
        this.map.jumpTo({center: [lng, lat], zoom: Math.max(this.map.getZoom(), FOCUS_ZOOM)})
      }
    })

    // The sheet takes room from the map on wide screens.
    this.resizeObserver = new ResizeObserver(() => this.map.resize())
    this.resizeObserver.observe(this.el)

    this.map.on("moveend", () => {
      const center = this.map.getCenter()
      storage.set(VIEW_KEY, {lat: center.lat, lng: center.lng, zoom: this.map.getZoom()})
      if (this.map.isStyleLoaded()) this.pushBounds()
    })
  },

  destroyed() {
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this.map) this.map.remove()
  },

  addPlaygroundLayers() {
    const map = this.map
    map.addSource("playgrounds", {
      type: "geojson",
      data: {type: "FeatureCollection", features: []},
      cluster: true,
      clusterRadius: 45,
      clusterMaxZoom: 15,
    })

    map.addLayer({
      id: "clusters",
      type: "circle",
      source: "playgrounds",
      filter: ["has", "point_count"],
      paint: {
        "circle-color": CLUSTER_COLOR,
        "circle-opacity": 0.85,
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 2,
        "circle-radius": ["step", ["get", "point_count"], 14, 10, 18, 100, 24],
      },
    })

    map.addLayer({
      id: "cluster-count",
      type: "symbol",
      source: "playgrounds",
      filter: ["has", "point_count"],
      layout: {"text-field": ["get", "point_count_abbreviated"], "text-size": 12},
      paint: {"text-color": "#ffffff"},
    })

    map.addLayer({
      id: "playgrounds",
      type: "circle",
      source: "playgrounds",
      filter: ["!", ["has", "point_count"]],
      paint: {
        "circle-color": ["case", ["get", "reviewed"], REVIEWED_COLOR, COLOR],
        "circle-radius": ["case", ["get", "reviewed"], 9, 6],
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 2,
      },
    })

    map.on("click", "clusters", async (e) => {
      const [cluster] = map.queryRenderedFeatures(e.point, {layers: ["clusters"]})
      const zoom = await map.getSource("playgrounds").getClusterExpansionZoom(cluster.properties.cluster_id)
      map.easeTo({center: cluster.geometry.coordinates, zoom})
    })

    map.on("click", "playgrounds", (e) => {
      const [playground] = e.features
      this.pushEvent("open", {id: playground.properties.id})
    })

    for (const layer of ["clusters", "playgrounds"]) {
      map.on("mouseenter", layer, () => { map.getCanvas().style.cursor = "pointer" })
      map.on("mouseleave", layer, () => { map.getCanvas().style.cursor = "" })
    }
  },

  // A right click, or a long press on touch screens, proposes to add a
  // playground there: a draggable marker with a popup to save it.
  listenForNewPlaygrounds() {
    this.map.on("contextmenu", (e) => this.proposePlayground(e.lngLat))

    let pressTimer = null
    const cancel = () => clearTimeout(pressTimer)
    this.map.on("touchstart", (e) => {
      cancel()
      if (e.originalEvent.touches.length === 1) {
        pressTimer = setTimeout(() => this.proposePlayground(e.lngLat), 600)
      }
    })
    for (const event of ["touchend", "touchcancel", "movestart", "zoomstart"]) this.map.on(event, cancel)
  },

  proposePlayground(lngLat) {
    if (!this.newMarker) {
      this.newMarker = new maplibregl.Marker({draggable: true, color: "#f59e0b"})
      this.newMarker.setPopup(new maplibregl.Popup({offset: 30, closeButton: false}).setDOMContent(this.newPlaygroundPopup()))
      this.newMarker.on("dragstart", () => this.newMarker.getPopup().remove())
      this.newMarker.on("dragend", () => this.newMarker.togglePopup())
    }
    this.newMarker.setLngLat(lngLat).addTo(this.map)
    if (!this.newMarker.getPopup().isOpen()) this.newMarker.togglePopup()
  },

  newPlaygroundPopup() {
    const labels = JSON.parse(this.el.dataset.addLabels)
    const content = document.createElement("div")
    content.className = "pe-new-playground"

    const hint = document.createElement("p")
    hint.textContent = labels.hint
    content.append(hint)

    const button = (label, className, onClick) => {
      const element = document.createElement("button")
      element.type = "button"
      element.className = className
      element.textContent = label
      element.addEventListener("click", onClick)
      content.append(element)
    }

    button(labels.save, "btn btn-primary btn-sm w-full", () => {
      const {lat, lng} = this.newMarker.getLngLat()
      this.pushEvent("add_playground", {lat, lng})
      this.removeNewMarker()
    })
    button(labels.remove, "btn btn-ghost btn-sm w-full", () => this.removeNewMarker())
    button(labels.back, "btn btn-ghost btn-sm w-full", () => this.newMarker.getPopup().remove())
    return content
  },

  removeNewMarker() {
    if (this.newMarker) this.newMarker.remove()
    this.newMarker = null
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
    let added = false
    for (const {id, lat, lng, name, reviewed} of playgrounds) {
      if (this.features.has(id)) continue
      this.features.set(id, {
        type: "Feature",
        id,
        geometry: {type: "Point", coordinates: [lng, lat]},
        properties: {id, name, reviewed},
      })
      added = true
    }
    if (added) this.refresh()
  },

  refresh() {
    const source = this.map.getSource("playgrounds")
    if (source) source.setData({type: "FeatureCollection", features: [...this.features.values()]})
  },
}

// Walking distance from the visitor to a playground, shown only when the
// visitor already allowed geolocation (the map's locate button asks for it).
export const DistanceHook = {
  mounted() {
    if (!navigator.geolocation || !navigator.permissions) return

    navigator.permissions.query({name: "geolocation"}).then(({state}) => {
      if (state !== "granted") return
      navigator.geolocation.getCurrentPosition(
        ({coords}) => this.show(coords),
        () => {},
        {maximumAge: 60000, timeout: 10000},
      )
    }).catch(() => {})
  },

  show({latitude, longitude}) {
    const target = new maplibregl.LngLat(parseFloat(this.el.dataset.lng), parseFloat(this.el.dataset.lat))
    const meters = new maplibregl.LngLat(longitude, latitude).distanceTo(target)
    const lang = document.documentElement.lang || undefined
    const distance = meters < 1000
      ? `${Math.round(meters).toLocaleString(lang)} m`
      : `${(meters / 1000).toLocaleString(lang, {maximumFractionDigits: 1})} km`
    this.el.textContent = this.el.dataset.template.replace("%{distance}", distance)
    this.el.hidden = false
  },
}
