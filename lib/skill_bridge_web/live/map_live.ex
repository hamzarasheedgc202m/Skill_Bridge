defmodule SkillBridgeWeb.MapLive do
  @moduledoc "Live location map — users see nearby workers in real time."
  use SkillBridgeWeb, :live_view
  embed_templates "map_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings
  alias SkillBridge.Location
  alias SkillBridge.PakistanLocations
  alias SkillBridge.Skills

  @impl true
  def mount(_params, session, socket) do
    current_user =
      case session["user_id"] do
        nil -> nil
        id -> Accounts.get_user(id)
      end

    if connected?(socket), do: Location.subscribe_locations()

    workers = Location.get_sharing_workers()
    categories = Skills.list_skill_categories()

    {:ok,
     socket
     |> assign(:page_title, "Live Map — SkillBridge")
     |> assign(:current_user, current_user)
     |> assign(:current_scope, if(current_user, do: current_user.role, else: nil))
     |> assign(:workers, workers)
     |> assign(:categories, categories)
     |> assign(:filter_category, "")
     |> assign(:selected_worker, nil)
     |> assign(:user_lat, nil)
     |> assign(:user_lng, nil)
     |> assign(:city_filter, "")
     |> assign(:location_label, nil)
     |> assign(:city_options, PakistanLocations.all_cities())
     |> assign(:live_booking, nil)
     |> assign(:live_booking_id, nil)
     |> push_workers_to_map(workers)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["booking_id"] do
        nil ->
          socket
          |> assign(:live_booking, nil)
          |> assign(:live_booking_id, nil)
          |> push_event("map:stop_tracking", %{})

        bid ->
          case Integer.parse(to_string(bid)) do
            {id, ""} ->
              user = socket.assigns[:current_user]

              if user && Bookings.booking_location_participant?(id, user.id) &&
                   Bookings.booking_open_for_location?(id) do
                booking = Bookings.get_booking!(id)

                socket
                |> assign(:live_booking, booking)
                |> assign(:live_booking_id, id)
                |> push_event("map:start_tracking", %{})
              else
                socket
                |> assign(:live_booking, nil)
                |> assign(:live_booking_id, nil)
                |> put_flash(:error, "You cannot share live location for that booking.")
              end

            _ ->
              socket |> assign(:live_booking, nil) |> assign(:live_booking_id, nil)
          end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => cid}, socket) do
    workers = workers_for_map(socket.assigns.workers, cid, socket.assigns.city_filter)

    {:noreply,
     socket
     |> assign(:filter_category, cid)
     |> push_event("map:workers", %{workers: Location.worker_map_payload(workers)})}
  end

  def handle_event("select_worker", %{"profile_id" => pid}, socket) do
    worker = Enum.find(socket.assigns.workers, &(to_string(&1.skilled_profile_id) == pid))
    {:noreply, assign(socket, :selected_worker, worker)}
  end

  def handle_event("user_location", %{"lat" => lat, "lng" => lng}, socket) do
    lat_f = parse_coord(lat)
    lng_f = parse_coord(lng)

    {:noreply,
     socket
     |> assign(:user_lat, lat_f)
     |> assign(:user_lng, lng_f)
     |> push_event("map:center_user", %{lat: lat_f, lng: lng_f})}
  end

  def handle_event("user_location_meta", params, socket) do
    label =
      params["label"] ||
        [params["city"], params["state"], params["country"]]
        |> Enum.reject(&(is_nil(&1) or &1 == ""))
        |> Enum.join(", ")

    city = params["city"] || ""

    {:noreply, socket |> assign(:location_label, label) |> assign(:city_filter, city)}
  end

  def handle_event("location_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("detect_my_location", _, socket) do
    {:noreply, push_event(socket, "map:detect_my_location", %{})}
  end

  def handle_event("filter_city", %{"city" => city}, socket) do
    workers = workers_for_map(socket.assigns.workers, socket.assigns.filter_category, city)

    {:noreply,
     socket
     |> assign(:city_filter, city)
     |> push_event("map:workers", %{workers: Location.worker_map_payload(workers)})}
  end

  def handle_event("close_worker", _, socket) do
    {:noreply, assign(socket, :selected_worker, nil)}
  end

  @impl true
  def handle_info({:location_update, %{profile_id: pid, lat: lat, lng: lng}}, socket) do
    workers =
      Enum.map(socket.assigns.workers, fn w ->
        if w.skilled_profile_id == pid, do: %{w | latitude: lat, longitude: lng}, else: w
      end)

    name =
      workers
      |> Enum.find(&(&1.skilled_profile_id == pid))
      |> case do
        nil -> "?"
        w -> w.skilled_profile.user.name
      end

    {:noreply,
     socket
     |> assign(:workers, workers)
     |> push_event("map:worker_moved", %{id: pid, lat: lat, lng: lng, name: name})}
  end

  defp push_workers_to_map(socket, workers) do
    push_event(socket, "map:workers", %{workers: Location.worker_map_payload(workers)})
  end

  defp workers_for_map(workers, category, city) do
    workers
    |> filtered_workers(category)
    |> filter_workers_by_city(city)
  end

  defp filtered_workers(workers, ""), do: workers

  defp filtered_workers(workers, cid) do
    cid_int = String.to_integer(cid)
    Enum.filter(workers, fn w -> w.skilled_profile.skill_category_id == cid_int end)
  end

  defp filter_workers_by_city(workers, ""), do: workers

  defp filter_workers_by_city(workers, city) do
    Enum.filter(workers, fn worker ->
      (worker.skilled_profile.city || "")
      |> String.downcase()
      |> String.contains?(String.downcase(city))
    end)
  end

  defp parse_coord(v) when is_float(v), do: v

  defp parse_coord(v) when is_integer(v), do: v * 1.0

  defp parse_coord(v) do
    case Float.parse(to_string(v)) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp distance(nil, _, _, _), do: nil
  defp distance(_, nil, _, _), do: nil

  defp distance(ulat, ulng, wlat, wlng) do
    r = 6371
    dlat = :math.pi() / 180 * (wlat - ulat)
    dlng = :math.pi() / 180 * (wlng - ulng)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(:math.pi() / 180 * ulat) * :math.cos(:math.pi() / 180 * wlat) *
          :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    Float.round(r * c, 1)
  end

  @impl true
  def render(assigns), do: index(assigns)
end
