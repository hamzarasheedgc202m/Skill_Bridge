import {Socket} from "phoenix"

let socket = null
const workersChannels = new Map()
const bookingChannels = new Map()

function csrfToken() {
  const el = document.querySelector("meta[name='csrf-token']")
  return el && el.getAttribute("content")
}

export function ensureUserSocket() {
  if (socket && socket.isConnected()) {
    return socket
  }

  socket = new Socket("/socket", {
    params: {_csrf_token: csrfToken()},
    reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000][Math.min(tries - 1, 3)]
  })

  socket.connect()
  return socket
}

function joinChannel(topic, handlers = {}) {
  const sock = ensureUserSocket()
  let ch = sock.channel(topic, {})

  ch.join()
    .receive("ok", () => {
      if (handlers.onJoin) handlers.onJoin()
    })
    .receive("error", (err) => {
      if (handlers.onError) handlers.onError(err)
    })

  if (handlers.onEvent) {
    Object.entries(handlers.onEvent).forEach(([event, fn]) => ch.on(event, fn))
  }

  return ch
}

export function pushWorkerPosition(lat, lng) {
  const topic = "location:workers"
  let ch = workersChannels.get(topic)

  if (!ch || ch.state === "closed") {
    ch = joinChannel(topic)
    workersChannels.set(topic, ch)
  }

  const send = () => ch.push("worker_position", {lat, lng})

  if (ch.state === "joined") {
    send()
  } else {
    ch.join().receive("ok", send)
  }
}

export function leaveWorkerChannel() {
  const ch = workersChannels.get("location:workers")
  if (ch) {
    ch.leave()
    workersChannels.delete("location:workers")
  }
}

export function joinBookingLocationChannel(bookingId, handlers = {}) {
  if (!bookingId) return null

  const topic = `location:booking:${bookingId}`
  const existing = bookingChannels.get(topic)
  if (existing) return existing

  const ch = joinChannel(topic, {
    onJoin: handlers.onJoin,
    onError: handlers.onError,
    onEvent: {
      peer_position: (payload) => {
        if (handlers.onPeer) handlers.onPeer(payload)
      }
    }
  })

  bookingChannels.set(topic, ch)
  return ch
}

export function pushPeerPosition(bookingId, lat, lng) {
  if (!bookingId) return

  const ch = joinBookingLocationChannel(bookingId)
  if (!ch) return

  const send = () => ch.push("peer_position", {lat, lng})

  if (ch.state === "joined") {
    send()
  } else {
    ch.join().receive("ok", send)
  }
}

export function leaveBookingChannel(bookingId) {
  const topic = `location:booking:${bookingId}`
  const ch = bookingChannels.get(topic)
  if (ch) {
    ch.leave()
    bookingChannels.delete(topic)
  }
}
