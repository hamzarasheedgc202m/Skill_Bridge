import {reverseGeocode} from "../services/location_api"

const DEFAULT_CENTER = [30.3753, 69.3451]  // Pakistan center
const DEFAULT_ZOOM   = 6

// ── Icon helpers ────────────────────────────────────────────────────────────

function workerIcon(initial) {
  return window.L.divIcon({
    html: `<div class="grid h-9 w-9 place-items-center rounded-full border-3 border-white bg-slate-900 text-xs font-bold text-white shadow">${initial}</div>`,
    className: "",
    iconSize: [36, 36],
    iconAnchor: [18, 18]
  })
}

function userIcon() {
  return window.L.divIcon({
    html: `<div class="grid h-8 w-8 place-items-center rounded-full border-3 border-white bg-emerald-600 text-sm text-white shadow">📍</div>`,
    className: "",
    iconSize: [32, 32],
    iconAnchor: [16, 16]
  })
}

function peerIcon(label) {
  return window.L.divIcon({
    html: `<div class="grid h-9 w-9 place-items-center rounded-full border-3 border-white bg-indigo-600 text-[10px] font-bold text-white shadow">${label}</div>`,
    className: "",
    iconSize: [36, 36],
    iconAnchor: [18, 18]
  })
}

// ── Leaflet readiness helper ─────────────────────────────────────────────────
// Leaflet is loaded via <script> tag at bottom of heex — may not be ready
// synchronously in mounted(). Poll until it appears, then init.

function whenLeafletReady(cb, attempts = 0) {
  if (window.L && window.L.map) {
    cb()
  } else if (attempts < 30) {
    setTimeout(() => whenLeafletReady(cb, attempts + 1), 100)
  } else {
    console.error("Leaflet failed to load after 3s")
  }
}

// ── LeafletMap (public map for users) ────────────────────────────────────────

const LeafletMap = {
  mounted() {
    this.markers       = {}
    this.userMarker    = null
    this.peerMarker    = null
    this.bookingChannel = null

    whenLeafletReady(() => this.initMap())
  },

  initMap() {
    this.map = window.L.map(this.el.id).setView(DEFAULT_CENTER, DEFAULT_ZOOM)

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
      maxZoom: 18
    }).addTo(this.map)

    this.handleEvent("map:detect_my_location", () => this.detectMyLocation())
    this.renderWorkers()

    const bookingId = this.el.dataset.bookingId
    if (bookingId) {
      import("../user_socket.js").then(({joinBookingLocationChannel}) => {
        this.bookingChannel = joinBookingLocationChannel(bookingId, {
          onPeer: (payload) => this.placePeerMarker(payload)
        })
      })
    }
  },

  updated() {
    if (!this.map) return
    this.renderWorkers()
    this.updateUserMarker()
  },

  destroyed() {
    if (this.bookingChannel) {
      this.bookingChannel.leave()
      this.bookingChannel = null
    }
  },

  renderWorkers() {
    if (!this.map) return
    let workers = []
    try { workers = JSON.parse(this.el.dataset.workers || "[]") } catch (_) {}

    const activeIds = new Set(workers.map((w) => String(w.id)))

    Object.keys(this.markers).forEach((id) => {
      if (!activeIds.has(String(id))) {
        this.map.removeLayer(this.markers[id])
        delete this.markers[id]
      }
    })

    workers.forEach((worker) => {
      if (this.markers[worker.id]) {
        this.markers[worker.id].setLatLng([worker.lat, worker.lng])
        return
      }
      const marker = window.L.marker([worker.lat, worker.lng], {
        icon: workerIcon((worker.name || "?").charAt(0))
      }).addTo(this.map)

      marker.bindPopup(
        `<b>${worker.name}</b><br>${worker.skill}${worker.rate ? `<br>PKR ${worker.rate}/hr` : ""}`
      )
      marker.on("click", () => this.pushEvent("select_worker", {profile_id: String(worker.id)}))
      this.markers[worker.id] = marker
    })
  },

  updateUserMarker() {
    const lat = Number(this.el.dataset.userLat)
    const lng = Number(this.el.dataset.userLng)
    if (!lat || !lng || !this.map) return   // 0,0 treated as unset

    if (this.userMarker) {
      this.userMarker.setLatLng([lat, lng])
    } else {
      this.userMarker = window.L.marker([lat, lng], {icon: userIcon()}).addTo(this.map)
      this.userMarker.bindPopup("Your approximate location")
    }
  },

  placePeerMarker(payload) {
    if (!this.map || !window.L) return
    const lat = Number(payload.lat)
    const lng = Number(payload.lng)
    if (!lat || !lng) return

    const label = payload.role === "professional" ? "Pro" : "Client"
    const title = payload.role === "professional" ? "Professional" : "Client"

    if (this.peerMarker) {
      this.peerMarker.setLatLng([lat, lng])
    } else {
      this.peerMarker = window.L.marker([lat, lng], {icon: peerIcon(label)}).addTo(this.map)
    }
    this.peerMarker.setIcon(peerIcon(label))
    this.peerMarker.bindPopup(`${title} (approximate area)`)
  },

  async detectMyLocation() {
    if (!navigator.geolocation) {
      this.pushEvent("location_error", {message: "Geolocation is not supported on this browser."})
      return
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude
        const lng = position.coords.longitude
        // Push to server — server will fuzz before storing
        this.pushEvent("user_location", {lat, lng})
        this.map.setView([lat, lng], 13)

        try {
          const location = await reverseGeocode(lat, lng)
          this.pushEvent("user_location_meta", location)
        } catch (_) {}
      },
      (err) => {
        const msg = err.code === 1
          ? "Location access denied. Please allow location in your browser settings."
          : "Could not get your location. Please try again."
        this.pushEvent("location_error", {message: msg})
      },
      {enableHighAccuracy: false, timeout: 10000, maximumAge: 60000}
    )
  }
}

// ── SkilledLocationMap (skilled person sets their working area) ───────────────

const SkilledLocationMap = {
  mounted() {
    this.map     = null
    this.marker  = null
    this.watchId = null

    whenLeafletReady(() => this.initMap())
  },

  initMap() {
    this.map = window.L.map(this.el.id).setView(DEFAULT_CENTER, DEFAULT_ZOOM)

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
      maxZoom: 18
    }).addTo(this.map)

    // Click on map to set approximate area
    this.map.on("click", async (event) => {
      await this.setLocation(event.latlng.lat, event.latlng.lng, true)
    })

    // Listen for the detect button event from LiveView
    this.handleEvent("location:detect", () => this.detectAndTrack())

    // If a saved location exists in dataset, show it
    this.updateFromDataset()
  },

  updated() {
    if (this.map) this.updateFromDataset()
  },

  destroyed() {
    this.stopTracking()
  },

  stopTracking() {
    if (this.watchId != null && navigator.geolocation) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
  },

  updateFromDataset() {
    // Only use dataset coords if they are real values (not empty or 0,0)
    const lat = parseFloat(this.el.dataset.lat)
    const lng = parseFloat(this.el.dataset.lng)
    if (lat && lng && !isNaN(lat) && !isNaN(lng)) {
      this.placeApproxMarker(lat, lng)
    }
  },

  // Show a CIRCLE (not a precise pin) to reinforce approximate nature
  placeApproxMarker(lat, lng) {
    if (!this.map) return

    // Remove old marker/circle
    if (this.marker) {
      this.map.removeLayer(this.marker)
    }

    // Draw a circle to represent approximate area (~500m radius)
    this.marker = window.L.circle([lat, lng], {
      radius:      500,
      color:       "#0f172a",
      fillColor:   "#0f172a",
      fillOpacity: 0.15,
      weight:      2
    }).addTo(this.map)

    this.map.setView([lat, lng], 14)
  },

  async setLocation(lat, lng, doReverseGeocode = false) {
    // Show circle on map (not exact pin)
    this.placeApproxMarker(lat, lng)

    // Send to server — server fuzzes before storing/broadcasting
    this.pushEvent("update_location", {lat, lng})

    // If sharing via channel, also push raw to channel (server fuzzes on receive)
    if (this.el.dataset.useWorkersChannel === "true") {
      import("../user_socket.js").then(({pushWorkerPosition}) => pushWorkerPosition(lat, lng))
    }

    if (!doReverseGeocode) return
    try {
      const location = await reverseGeocode(lat, lng)
      // Only send city/area name — not coords
      this.pushEvent("location_selected", location)
    } catch (_) {}
  },

  detectAndTrack() {
    if (!navigator.geolocation) {
      this.pushEvent("location_error", {message: "Geolocation is not supported on this browser."})
      return
    }

    // Stop any existing watch
    this.stopTracking()

    const options = {
      enableHighAccuracy: false,  // low accuracy = less battery, less precise = more private
      timeout:            10000,
      maximumAge:         30000
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        await this.setLocation(position.coords.latitude, position.coords.longitude, true)
      },
      (err) => {
        const msg = err.code === 1
          ? "Location access denied. Please allow location in your browser settings, then try again."
          : "Could not detect location. Please tap the map to set your area manually."
        this.pushEvent("location_error", {message: msg})
      },
      options
    )

    // Watch for updates every ~30s (not continuously) — push to server which fuzzes
    this.watchId = navigator.geolocation.watchPosition(
      async (position) => {
        await this.setLocation(position.coords.latitude, position.coords.longitude, false)
      },
      () => {},  // silent on watch errors
      {...options, maximumAge: 30000}
    )
  }
}

export default {
  LeafletMap,
  SkilledLocationMap
}

