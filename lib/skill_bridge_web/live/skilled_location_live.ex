defmodule SkillBridgeWeb.SkilledLocationLive do
  use SkillBridgeWeb, :live_view
  embed_templates "skilled_location_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Location

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    profile = Skills.get_skilled_profile_by_user_id(user.id)
    loc = profile && Location.get_worker_location(profile.id)
    sharing = (loc && loc.is_sharing) || false

    {:ok,
     socket
     |> assign(:page_title, "My Location")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:profile, profile)
     |> assign(:sharing, sharing)
     # Never expose exact GPS — only store whether we have a location
     |> assign(:has_location, not is_nil(loc))
     |> assign(:location_label, nil)}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("toggle_sharing", _, socket) do
    profile = socket.assigns.profile

    unless profile do
      {:noreply, put_flash(socket, :error, "Create your profile first.")}
    else
      new_sharing = !socket.assigns.sharing
      Location.toggle_sharing(profile.id, new_sharing)

      {:noreply,
       socket
       |> assign(:sharing, new_sharing)
       |> put_flash(
         :info,
         if(new_sharing,
           do: "Location sharing ON — clients will see your approximate area",
           else: "Location sharing OFF"
         )
       )}
    end
  end

  # Receives GPS from the browser — fuzz and store, never echo exact coords back
  def handle_event("update_location", %{"lat" => lat, "lng" => lng}, socket) do
    profile = socket.assigns.profile

    if profile && socket.assigns.sharing do
      # Fuzzing happens inside upsert_location and broadcast_location
      {:ok, _} = Location.upsert_location(profile.id, lat, lng, true)
      Location.broadcast_location(profile.id, lat, lng)

      # Mark that we have a location but don't assign raw coords to socket
      {:noreply, assign(socket, :has_location, true)}
    else
      {:noreply, socket}
    end
  end

  # Reverse-geocode label from JS (city/area name — safe to show)
  def handle_event("location_selected", params, socket) do
    label =
      [params["city"], params["state"], params["country"]]
      |> Enum.reject(&is_nil_or_empty/1)
      |> Enum.join(", ")

    {:noreply, assign(socket, :location_label, label)}
  end

  def handle_event("location_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("detect_location", _, socket) do
    {:noreply, push_event(socket, "location:detect", %{})}
  end

  defp is_nil_or_empty(nil), do: true
  defp is_nil_or_empty(""), do: true
  defp is_nil_or_empty(_), do: false

  @impl true
  def render(assigns), do: index(assigns)
end
