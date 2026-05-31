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

    socket =
      socket
      |> assign(:page_title, "My Location")
      |> assign(:current_user, user)
      |> assign(:current_scope, user.role)
      |> assign(:profile, profile)
      |> assign(:sharing, sharing)
      |> assign(:has_location, loc != nil && loc.latitude != nil)
      |> assign(:map_lat, loc && loc.latitude)
      |> assign(:map_lng, loc && loc.longitude)
      |> assign(:location_label, nil)

    socket =
      if connected?(socket) && sharing do
        push_event(socket, "location:sharing_changed", %{enabled: true})
      else
        socket
      end

    {:ok, socket}
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

      socket =
        socket
        |> assign(:sharing, new_sharing)
        |> push_event("location:sharing_changed", %{enabled: new_sharing})
        |> put_flash(
          :info,
          if(new_sharing,
            do: "Live sharing ON — your position updates every few seconds on the map",
            else: "Live sharing OFF"
          )
        )

      socket =
        if new_sharing do
          push_event(socket, "location:detect", %{})
        else
          socket
        end

      {:noreply, socket}
    end
  end

  def handle_event("update_location", %{"lat" => lat, "lng" => lng}, socket) do
    profile = socket.assigns.profile

    if profile && socket.assigns.sharing do
      case Location.upsert_location(profile.id, lat, lng, true) do
        {:ok, loc} ->
          {:noreply,
           socket
           |> assign(:has_location, true)
           |> assign(:map_lat, loc.latitude)
           |> assign(:map_lng, loc.longitude)
           |> push_event("location:set_marker", %{lat: loc.latitude, lng: loc.longitude})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not save location.")}
      end
    else
      {:noreply, socket}
    end
  end

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
