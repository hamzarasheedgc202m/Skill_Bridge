const NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

export async function reverseGeocode(lat, lng) {
  const url = new URL(NOMINATIM_URL)
  url.searchParams.set("lat", String(lat))
  url.searchParams.set("lon", String(lng))
  url.searchParams.set("format", "jsonv2")

  const response = await fetch(url.toString(), {
    headers: {
      "Accept": "application/json"
    }
  })

  if (!response.ok) {
    throw new Error("Failed to resolve location details.")
  }

  const payload = await response.json()
  const address = payload.address || {}

  return {
    label: payload.display_name || "",
    city: address.city || address.town || address.village || "",
    state: address.state || "",
    country: address.country || ""
  }
}
