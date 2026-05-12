import {Socket} from "phoenix"

let socket = null
let workersChannel = null

function csrfToken() {
  const el = document.querySelector("meta[name='csrf-token']")
  return el && el.getAttribute("content")
}

export function ensureUserSocket() {
  if (socket && socket.isConnected()) {
    return socket
  }

  const token = csrfToken()
  socket = new Socket("/socket", {params: {_csrf_token: token}})
  socket.connect()
  return socket
}

export function pushWorkerPosition(lat, lng) {
  const sock = ensureUserSocket()

  if (!workersChannel || workersChannel.socket !== sock) {
    workersChannel = sock.channel("location:workers", {})
  }

  const ch = workersChannel
  const send = () => ch.push("worker_position", {lat, lng})

  if (ch.state === "joined") {
    send()
  } else {
    ch
      .join()
      .receive("ok", send)
      .receive("error", () => {
        workersChannel = null
      })
  }
}

export function joinBookingLocationChannel(bookingId, handlers) {
  if (!bookingId) return null

  const topic = `location:booking:${bookingId}`
  const ch = ensureUserSocket().channel(topic, {})

  ch.join()
    .receive("ok", () => {
      if (handlers && handlers.onJoin) handlers.onJoin()
    })
    .receive("error", () => {
      if (handlers && handlers.onError) handlers.onError()
    })

  ch.on("peer_position", (payload) => {
    if (handlers && handlers.onPeer) handlers.onPeer(payload)
  })

  return ch
}
