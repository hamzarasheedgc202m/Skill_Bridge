defmodule SkillBridgeWeb.LocationChannel do
  @moduledoc """
  Real-time location updates over Phoenix Channels.

  Topics:
  - `location:workers` — skilled users push GPS while sharing is ON
  - `location:booking:<id>` — client + professional ephemeral peer positions
  """
  use SkillBridgeWeb, :channel

  alias SkillBridge.{Accounts, Bookings, Location, Skills}

  @impl true
  def join("location:workers", _payload, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    if user.role == "skilled_person" do
      {:ok, assign(socket, :user_role, user.role)}
    else
      {:error, %{reason: "skilled_only"}}
    end
  end

  def join("location:booking:" <> booking_id_str, _payload, socket) do
    case Integer.parse(booking_id_str) do
      {booking_id, ""} ->
        user_id = socket.assigns.user_id

        with true <- Bookings.booking_location_participant?(booking_id, user_id),
             {:ok, role} <- Bookings.booking_location_role(booking_id, user_id),
             true <- Bookings.booking_open_for_location?(booking_id) do
          {:ok,
           socket
           |> assign(:booking_id, booking_id)
           |> assign(:booking_role, role)}
        else
          _ -> {:error, %{reason: "not_allowed"}}
        end

      _ ->
        {:error, %{reason: "invalid_booking"}}
    end
  end

  def join("location:" <> _, _payload, _socket), do: {:error, %{reason: "unknown_topic"}}

  @impl true
  def handle_in("worker_position", %{"lat" => lat, "lng" => lng}, socket) do
    user_id = socket.assigns.user_id

    if socket.assigns.user_role != "skilled_person" do
      {:reply, {:error, %{reason: "skilled_only"}}, socket}
    else
      case parse_lat_lng(lat, lng) do
        {:ok, latf, lngf} ->
          case Skills.get_skilled_profile_by_user_id(user_id) do
            nil ->
              {:reply, {:error, %{reason: "no_profile"}}, socket}

            profile ->
              loc = Location.get_worker_location(profile.id)

              if loc == nil || loc.is_sharing do
                case Location.upsert_location(profile.id, latf, lngf, true) do
                  {:ok, _} ->
                    {:reply, :ok, assign(socket, :revoke_sharing_on_leave, true)}

                  {:error, cs} ->
                    {:reply, {:error, %{reason: "db", errors: cs.errors}}, socket}
                end
              else
                {:reply, {:error, %{reason: "sharing_off"}}, socket}
              end
          end

        :error ->
          {:reply, {:error, %{reason: "invalid_coords"}}, socket}
      end
    end
  end

  def handle_in("peer_position", %{"lat" => lat, "lng" => lng}, socket) do
    if !Map.has_key?(socket.assigns, :booking_id) do
      {:noreply, socket}
    else
      case parse_lat_lng(lat, lng) do
        {:ok, latf, lngf} ->
          {flat, flng} = Location.fuzz_coordinates(latf, lngf)

          broadcast_from!(socket, "peer_position", %{
            lat: flat,
            lng: flng,
            role: socket.assigns.booking_role
          })

          {:noreply, socket}

        :error ->
          {:noreply, socket}
      end
    end
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:revoke_sharing_on_leave] do
      Location.revoke_sharing_for_skilled_user(socket.assigns.user_id)
    end

    :ok
  end

  defp parse_lat_lng(lat, lng) do
    with {latf, _} <- float_pair(lat),
         {lngf, _} <- float_pair(lng),
         true <- latf >= -90.0 and latf <= 90.0,
         true <- lngf >= -180.0 and lngf <= 180.0 do
      {:ok, latf, lngf}
    else
      _ -> :error
    end
  end

  defp float_pair(v) do
    case Float.parse(to_string(v)) do
      {f, _} -> {f, ""}
      :error -> :error
    end
  end
end
