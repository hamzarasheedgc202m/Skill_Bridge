defmodule SkillBridge.Location do
  @moduledoc """
  Manages worker live-location sharing with privacy protection.

  Coordinates are fuzzed before storage and broadcast so exact addresses are not exposed.
  """

  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Location.WorkerLocation
  alias SkillBridge.Skills.SkilledProfile

  @fuzz_min 0.003
  @fuzz_max 0.008

  def fuzz_coordinates(lat, lng) when is_float(lat) and is_float(lng) do
    range = @fuzz_max - @fuzz_min
    dlat = @fuzz_min + :rand.uniform() * range
    dlng = @fuzz_min + :rand.uniform() * range
    dlat = if :rand.uniform() > 0.5, do: dlat, else: -dlat
    dlng = if :rand.uniform() > 0.5, do: dlng, else: -dlng
    {Float.round(lat + dlat, 5), Float.round(lng + dlng, 5)}
  end

  def fuzz_coordinates(lat, lng) do
    with {lat_f, _} <- Float.parse(to_string(lat)),
         {lng_f, _} <- Float.parse(to_string(lng)) do
      fuzz_coordinates(lat_f, lng_f)
    else
      _ -> {lat, lng}
    end
  end

  def upsert_location(skilled_profile_id, lat, lng, sharing \\ true) do
    {flat, flng} = fuzz_coordinates(lat, lng)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    existing = Repo.get_by(WorkerLocation, skilled_profile_id: skilled_profile_id)

    attrs = %{
      skilled_profile_id: skilled_profile_id,
      latitude: flat,
      longitude: flng,
      is_sharing: sharing,
      last_seen_at: now
    }

    result =
      case existing do
        nil ->
          %WorkerLocation{}
          |> WorkerLocation.changeset(attrs)
          |> Repo.insert()

        rec ->
          rec
          |> WorkerLocation.changeset(attrs)
          |> Repo.update()
      end

    case result do
      {:ok, loc} ->
        broadcast_worker_location(loc)
        {:ok, loc}

      error ->
        error
    end
  end

  def toggle_sharing(skilled_profile_id, sharing) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.get_by(WorkerLocation, skilled_profile_id: skilled_profile_id) do
      nil when sharing ->
        # No row yet — first GPS fix will upsert via LocationChannel / LiveView.
        {:ok, :awaiting_position}

      nil ->
        {:ok, nil}

      rec ->
        case rec
             |> Ecto.Changeset.change(%{is_sharing: sharing, last_seen_at: now})
             |> Repo.update() do
          {:ok, loc} = ok ->
            if sharing, do: broadcast_worker_location(loc)
            ok

          error ->
            error
        end
    end
  end

  def get_sharing_workers do
    WorkerLocation
    |> where([w], w.is_sharing == true)
    |> where([w], not is_nil(w.latitude) and not is_nil(w.longitude))
    |> preload([w], skilled_profile: [:user, :skill_category])
    |> Repo.all()
  end

  def get_worker_location(skilled_profile_id) do
    Repo.get_by(WorkerLocation, skilled_profile_id: skilled_profile_id)
  end

  @doc "Broadcasts the stored (fuzzed) coordinates for a worker."
  def broadcast_worker_location(%WorkerLocation{is_sharing: true} = loc)
      when is_number(loc.latitude) and is_number(loc.longitude) do
    Phoenix.PubSub.broadcast(
      SkillBridge.PubSub,
      "locations",
      {:location_update,
       %{
         profile_id: loc.skilled_profile_id,
         lat: loc.latitude,
         lng: loc.longitude
       }}
    )
  end

  def broadcast_worker_location(_), do: :ok

  @doc "Legacy helper — upserts then broadcasts stored coords."
  def broadcast_location(skilled_profile_id, lat, lng) do
    case upsert_location(skilled_profile_id, lat, lng, true) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  def subscribe_locations do
    Phoenix.PubSub.subscribe(SkillBridge.PubSub, "locations")
  end

  def revoke_sharing_for_skilled_user(user_id) when is_integer(user_id) do
    case Repo.get_by(SkilledProfile, user_id: user_id) do
      nil -> :ok
      profile -> _ = toggle_sharing(profile.id, false)
    end

    :ok
  end

  def worker_map_payload(workers) when is_list(workers) do
    Enum.map(workers, fn w ->
      %{
        id: w.skilled_profile_id,
        lat: w.latitude,
        lng: w.longitude,
        name: w.skilled_profile.user.name,
        skill: w.skilled_profile.skill_category.name,
        rate: w.skilled_profile.hourly_rate_cents
      }
    end)
  end
end
