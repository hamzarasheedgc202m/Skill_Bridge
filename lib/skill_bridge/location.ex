defmodule SkillBridge.Location do
  @moduledoc """
  Manages worker live-location sharing with privacy protection.

  Exact GPS coordinates are NEVER stored or broadcast. All coordinates are
  fuzed by a random offset of 300–800 metres before being persisted or sent
  to clients, so a worker's precise address cannot be determined from the map.
  """

  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Location.WorkerLocation
  alias SkillBridge.Skills.SkilledProfile

  # Fuzz radius in degrees.
  # 0.005° ≈ 500 m at Pakistan's latitude — keeps worker in right neighbourhood
  # but hides their exact street/house.
  @fuzz_min 0.003
  @fuzz_max 0.008

  @doc """
  Applies a reproducible-but-random lat/lng offset so the exact location is
  never revealed. The offset changes each call so it cannot be averaged out.
  """
  def fuzz_coordinates(lat, lng) when is_float(lat) and is_float(lng) do
    range = @fuzz_max - @fuzz_min
    dlat = @fuzz_min + :rand.uniform() * range
    dlng = @fuzz_min + :rand.uniform() * range
    # Randomly flip sign so fuzzing goes in all 4 directions
    dlat = if :rand.uniform() > 0.5, do: dlat, else: -dlat
    dlng = if :rand.uniform() > 0.5, do: dlng, else: -dlng
    {Float.round(lat + dlat, 5), Float.round(lng + dlng, 5)}
  end

  def fuzz_coordinates(lat, lng) do
    # Handle string coords from JS events
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

    case existing do
      nil ->
        %WorkerLocation{}
        |> WorkerLocation.changeset(%{
          skilled_profile_id: skilled_profile_id,
          latitude: flat,
          longitude: flng,
          is_sharing: sharing,
          last_seen_at: now
        })
        |> Repo.insert()

      rec ->
        rec
        |> WorkerLocation.changeset(%{
          latitude: flat,
          longitude: flng,
          is_sharing: sharing,
          last_seen_at: now
        })
        |> Repo.update()
    end
  end

  def toggle_sharing(skilled_profile_id, sharing) do
    case Repo.get_by(WorkerLocation, skilled_profile_id: skilled_profile_id) do
      nil ->
        {:ok, nil}

      rec ->
        rec
        |> Ecto.Changeset.change(%{is_sharing: sharing})
        |> Repo.update()
    end
  end

  def get_sharing_workers do
    WorkerLocation
    |> where([w], w.is_sharing == true)
    |> preload([w], skilled_profile: [:user, :skill_category])
    |> Repo.all()
  end

  def get_worker_location(skilled_profile_id) do
    Repo.get_by(WorkerLocation, skilled_profile_id: skilled_profile_id)
  end

  def broadcast_location(skilled_profile_id, lat, lng) do
    # Fuzz again before broadcasting so live updates are also approximate
    {flat, flng} = fuzz_coordinates(lat, lng)

    Phoenix.PubSub.broadcast(
      SkillBridge.PubSub,
      "locations",
      {:location_update, %{profile_id: skilled_profile_id, lat: flat, lng: flng}}
    )
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
end
