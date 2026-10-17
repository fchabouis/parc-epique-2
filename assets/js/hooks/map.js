import maplibregl from "../../vendor/maplibre-gl/maplibre-gl.js"

const DEFAULT_VIEW = {lat: 48.85, lng: 2.34, zoom: 13}
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
// clustered GeoJSON source.
export const MapHook = {
  mounted() {
    const saved = savedView()
    const view = saved || DEFAULT_VIEW

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
      if (!saved) this.geolocate.trigger()
    })

    this.map.on("moveend", () => {
      const center = this.map.getCenter()
      storage.set(VIEW_KEY, {lat: center.lat, lng: center.lng, zoom: this.map.getZoom()})
      if (this.map.isStyleLoaded()) this.pushBounds()
    })
  },

  destroyed() {
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

    for (const layer of ["clusters", "playgrounds"]) {
      map.on("mouseenter", layer, () => { map.getCanvas().style.cursor = "pointer" })
      map.on("mouseleave", layer, () => { map.getCanvas().style.cursor = "" })
    }
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
    if (added) {
      this.map.getSource("playgrounds").setData({type: "FeatureCollection", features: [...this.features.values()]})
    }
  },
}
