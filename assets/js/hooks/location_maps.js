import {reverseGeocode} from "../services/location_api"
import {
  joinBookingLocationChannel,
  leaveBookingChannel,
  leaveWorkerChannel,
  pushPeerPosition,
  pushWorkerPosition
} from "../user_socket"

const DEFAULT_CENTER = [30.3753, 69.3451]
const DEFAULT_ZOOM = 6
const TRACK_OPTIONS = {
  enableHighAccuracy: true,
  maximumAge: 5000,
  timeout: 15000
}

function whenLeafletReady(cb, attempts = 0) {
  if (window.L && window.L.map) {
    cb()
  } else if (attempts < 40) {
    setTimeout(() => whenLeafletReady(cb, attempts + 1), 100)
  } else {
    console.error("Leaflet failed to load")
  }
}

function workerIcon(initial) {
  return window.L.divIcon({
    html: `<div class="grid h-10 w-10 place-items-center rounded-full border-[3px] border-white bg-slate-900 text-xs font-bold text-white shadow-lg">${initial}</div>`,
    className: "",
    iconSize: [40, 40],
    iconAnchor: [20, 20]
  })
}

function userIcon() {
  return window.L.divIcon({
    html: `<div class="relative"><div class="absolute inset-0 animate-ping rounded-full bg-emerald-400 opacity-40"></div><div class="relative grid h-9 w-9 place-items-center rounded-full border-[3px] border-white bg-emerald-600 text-white shadow-lg">📍</div></div>`,
    className: "",
    iconSize: [36, 36],
    iconAnchor: [18, 18]
  })
}

function peerIcon(label, color) {
  return window.L.divIcon({
    html: `<div class="grid h-10 w-10 place-items-center rounded-full border-[3px] border-white text-[10px] font-bold text-white shadow-lg" style="background:${color}">${label}</div>`,
    className: "",
    iconSize: [40, 40],
    iconAnchor: [20, 20]
  })
}

function parseWorkers(raw) {
  try {
    return JSON.parse(raw || "[]")
  } catch (_) {
    return []
  }
}

function moveMarker(marker, lat, lng, map) {
  if (!marker) return
  marker.setLatLng([lat, lng])
  if (map && !map.getBounds().contains([lat, lng])) {
    map.panTo([lat, lng], {animate: true, duration: 0.5})
  }
}

function startWatch(callback) {
  if (!navigator.geolocation) return null

  navigator.geolocation.getCurrentPosition(
    (pos) => callback(pos.coords.latitude, pos.coords.longitude),
    () => {},
    TRACK_OPTIONS
  )

  return navigator.geolocation.watchPosition(
    (pos) => callback(pos.coords.latitude, pos.coords.longitude),
    () => {},
    TRACK_OPTIONS
  )
}

function stopWatch(watchId) {
  if (watchId != null && navigator.geolocation) {
    navigator.geolocation.clearWatch(watchId)
  }
}

// ── Public map (clients + booking live track) ─────────────────────────────

const LeafletMap = {
  mounted() {
    this.markers = {}
    this.userMarker = null
    this.peerMarker = null
    this.watchId = null
    this.bookingId = this.el.dataset.bookingId || ""

    whenLeafletReady(() => this.initMap())
  },

  initMap() {
    this.map = window.L.map(this.el.id).setView(DEFAULT_CENTER, DEFAULT_ZOOM)

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap",
      maxZoom: 19
    }).addTo(this.map)

    this.renderWorkers(parseWorkers(this.el.dataset.workers))
    this.updateUserMarker(this.el.dataset.userLat, this.el.dataset.userLng)

    this.handleEvent("map:workers", ({workers}) => this.renderWorkers(workers))
    this.handleEvent("map:worker_moved", (w) => this.moveWorker(w))
    this.handleEvent("map:center_user", ({lat, lng}) => {
      this.updateUserMarker(lat, lng)
      if (this.map) this.map.setView([lat, lng], 14)
    })
    this.handleEvent("map:peer", (payload) => this.placePeerMarker(payload))
    this.handleEvent("map:detect_my_location", () => this.detectMyLocation())
    this.handleEvent("map:start_tracking", () => this.startLiveTracking())
    this.handleEvent("map:stop_tracking", () => this.stopLiveTracking())

    if (this.bookingId) {
      this.bookingChannel = joinBookingLocationChannel(this.bookingId, {
        onPeer: (payload) => this.placePeerMarker(payload)
      })
      this.startLiveTracking()
    }
  },

  destroyed() {
    this.stopLiveTracking()
    if (this.bookingId) leaveBookingChannel(this.bookingId)
  },

  renderWorkers(workers) {
    if (!this.map) return

    const activeIds = new Set(workers.map((w) => String(w.id)))

    Object.keys(this.markers).forEach((id) => {
      if (!activeIds.has(String(id))) {
        this.map.removeLayer(this.markers[id])
        delete this.markers[id]
      }
    })

    workers.forEach((worker) => {
      const lat = Number(worker.lat)
      const lng = Number(worker.lng)
      if (!lat || !lng) return

      if (this.markers[worker.id]) {
        moveMarker(this.markers[worker.id], lat, lng, this.map)
        return
      }

      const marker = window.L.marker([lat, lng], {
        icon: workerIcon((worker.name || "?").charAt(0).toUpperCase())
      }).addTo(this.map)

      marker.bindPopup(
        `<b>${worker.name}</b><br>${worker.skill}${worker.rate ? `<br>PKR ${Math.round(worker.rate / 100)}/hr` : ""}<br><small>Live · approximate area</small>`
      )
      marker.on("click", () => this.pushEvent("select_worker", {profile_id: String(worker.id)}))
      this.markers[worker.id] = marker
    })
  },

  moveWorker({id, lat, lng}) {
    const latN = Number(lat)
    const lngN = Number(lng)
    if (!latN || !lngN) return

    if (this.markers[id]) {
      moveMarker(this.markers[id], latN, lngN, this.map)
    } else {
      this.renderWorkers([{id, lat: latN, lng: lngN, name: "?", skill: ""}])
    }
  },

  updateUserMarker(lat, lng) {
    const latN = Number(lat)
    const lngN = Number(lng)
    if (!this.map || !latN || !lngN) return

    if (this.userMarker) {
      moveMarker(this.userMarker, latN, lngN, this.map)
    } else {
      this.userMarker = window.L.marker([latN, lngN], {icon: userIcon()}).addTo(this.map)
      this.userMarker.bindPopup("You (live)")
    }
  },

  placePeerMarker(payload) {
    if (!this.map) return
    const lat = Number(payload.lat)
    const lng = Number(payload.lng)
    if (!lat || !lng) return

    const isPro = payload.role === "professional"
    const label = isPro ? "Pro" : "Client"
    const color = isPro ? "#4f46e5" : "#0d9488"

    if (this.peerMarker) {
      this.peerMarker.setLatLng([lat, lng])
      this.peerMarker.setIcon(peerIcon(label, color))
    } else {
      this.peerMarker = window.L.marker([lat, lng], {icon: peerIcon(label, color)}).addTo(this.map)
    }
    this.peerMarker.bindPopup(`${label} (live · approximate)`)
    this.map.fitBounds(
      window.L.latLngBounds([
        [lat, lng],
        this.userMarker ? this.userMarker.getLatLng() : [lat, lng]
      ]).pad(0.2),
      {maxZoom: 15}
    )
  },

  startLiveTracking() {
    if (this.watchId != null) return

    this.watchId = startWatch((lat, lng) => {
      this.updateUserMarker(lat, lng)
      this.pushEvent("user_location", {lat, lng})

      if (this.bookingId) {
        pushPeerPosition(this.bookingId, lat, lng)
      }
    })
  },

  stopLiveTracking() {
    stopWatch(this.watchId)
    this.watchId = null
  },

  async detectMyLocation() {
    if (!navigator.geolocation) {
      this.pushEvent("location_error", {message: "Geolocation is not supported."})
      return
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude
        const lng = position.coords.longitude
        this.pushEvent("user_location", {lat, lng})
        if (this.map) this.map.setView([lat, lng], 14)
        this.updateUserMarker(lat, lng)
        this.startLiveTracking()

        try {
          const location = await reverseGeocode(lat, lng)
          this.pushEvent("user_location_meta", location)
        } catch (_) {}
      },
      (err) => {
        const msg = err.code === 1
          ? "Location access denied. Allow location in browser settings."
          : "Could not get your location."
        this.pushEvent("location_error", {message: msg})
      },
      TRACK_OPTIONS
    )
  }
}

// ── Skilled worker map (share + profile pin) ────────────────────────────────

const SkilledLocationMap = {
  mounted() {
    this.map = null
    this.marker = null
    this.watchId = null
    this.tracking = false

    whenLeafletReady(() => this.initMap())
  },

  initMap() {
    this.map = window.L.map(this.el.id).setView(DEFAULT_CENTER, DEFAULT_ZOOM)

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap",
      maxZoom: 19
    }).addTo(this.map)

    this.map.on("click", async (e) => {
      await this.setLocation(e.latlng.lat, e.latlng.lng, true)
    })

    this.handleEvent("location:detect", () => this.startTracking())
    this.handleEvent("location:stop_tracking", () => this.stopTracking())
    this.handleEvent("location:sharing_changed", ({enabled}) => {
      if (enabled) this.startTracking()
      else this.stopTracking()
    })
    this.handleEvent("location:set_marker", ({lat, lng}) => {
      this.placeApproxMarker(Number(lat), Number(lng))
    })

    const lat = parseFloat(this.el.dataset.lat)
    const lng = parseFloat(this.el.dataset.lng)
    if (lat && lng && !isNaN(lat) && !isNaN(lng)) {
      this.placeApproxMarker(lat, lng)
    }

    if (this.el.dataset.tracking === "true") {
      this.startTracking()
    }
  },

  destroyed() {
    this.stopTracking()
    leaveWorkerChannel()
  },

  stopTracking() {
    this.tracking = false
    stopWatch(this.watchId)
    this.watchId = null
  },

  placeApproxMarker(lat, lng) {
    if (!this.map || !lat || !lng) return

    if (this.marker) this.map.removeLayer(this.marker)

    this.marker = window.L.circle([lat, lng], {
      radius: 500,
      color: "#0f172a",
      fillColor: "#0f172a",
      fillOpacity: 0.15,
      weight: 2
    }).addTo(this.map)

    this.map.setView([lat, lng], 14)
  },

  async setLocation(lat, lng, doReverseGeocode = false) {
    this.placeApproxMarker(lat, lng)
    this.pushEvent("update_location", {lat, lng})

    if (this.el.dataset.useWorkersChannel === "true") {
      pushWorkerPosition(lat, lng)
    }

    if (!doReverseGeocode) return
    try {
      const location = await reverseGeocode(lat, lng)
      this.pushEvent("location_selected", location)
    } catch (_) {}
  },

  startTracking() {
    if (!navigator.geolocation) {
      this.pushEvent("location_error", {message: "Geolocation is not supported."})
      return
    }

    stopWatch(this.watchId)
    this.watchId = null

    this.watchId = startWatch(async (lat, lng) => {
      await this.setLocation(lat, lng, false)
    })

    navigator.geolocation.getCurrentPosition(
      async (pos) => await this.setLocation(pos.coords.latitude, pos.coords.longitude, true),
      (err) => {
        const msg = err.code === 1
          ? "Location denied. Allow access or tap the map to set your area."
          : "Could not detect location. Tap the map to set your area."
        this.pushEvent("location_error", {message: msg})
      },
      TRACK_OPTIONS
    )
  }
}

export default {
  LeafletMap,
  SkilledLocationMap
}
