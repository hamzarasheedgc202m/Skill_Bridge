defmodule SkillBridge.Skills do
  @moduledoc "Context for skill categories, skilled profiles, and availability."
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Accounts.User
  alias SkillBridge.Location.WorkerLocation
  alias SkillBridge.Skills.{SkillCategory, SkilledProfile, AvailabilitySlot}

  # ── Categories ────────────────────────────────────────────────────────────
  def list_skill_categories, do: Repo.all(SkillCategory)
  def get_skill_category!(id), do: Repo.get!(SkillCategory, id)
  def get_skill_category_by_slug(slug), do: Repo.get_by(SkillCategory, slug: slug)

  def create_skill_category(attrs) do
    %SkillCategory{} |> SkillCategory.changeset(attrs) |> Repo.insert()
  end

  # ── Profiles ──────────────────────────────────────────────────────────────
  def list_skilled_profiles(opts \\ []) do
    approved_only = Keyword.get(opts, :approved_only, true)
    category_id = Keyword.get(opts, :skill_category_id)
    region = Keyword.get(opts, :region)
    province = Keyword.get(opts, :province)
    city = Keyword.get(opts, :city)
    search = Keyword.get(opts, :search)

    SkilledProfile
    |> maybe_filter_approved(approved_only)
    |> maybe_filter_category(category_id)
    |> maybe_filter_region(region)
    |> maybe_filter_province(province)
    |> maybe_filter_city(city)
    |> maybe_filter_search(search)
    |> preload([:user, :skill_category, :availability_slots])
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, term) do
    pattern = "%#{String.downcase(term)}%"

    from p in query,
      join: u in assoc(p, :user),
      join: c in assoc(p, :skill_category),
      where:
        ilike(p.bio, ^pattern) or
          ilike(p.city, ^pattern) or
          ilike(p.province, ^pattern) or
          ilike(u.name, ^pattern) or
          ilike(c.name, ^pattern)
  end

  def list_all_skilled_profiles do
    SkilledProfile
    |> preload([:user, :skill_category])
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  def list_pending_skilled_profiles do
    SkilledProfile
    |> where([p], p.status == "pending" or is_nil(p.approved_at))
    |> preload([:user, :skill_category])
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_approved(query, false), do: query

  defp maybe_filter_approved(query, true),
    do: where(query, [p], p.status == "approved" and not is_nil(p.approved_at))

  defp maybe_filter_category(query, nil), do: query
  defp maybe_filter_category(query, id), do: where(query, [p], p.skill_category_id == ^id)
  defp maybe_filter_region(query, nil), do: query
  defp maybe_filter_region(query, ""), do: query

  defp maybe_filter_region(query, r),
    do:
      where(
        query,
        [p],
        ilike(p.region, ^"%#{r}%") or ilike(p.city, ^"%#{r}%") or ilike(p.district, ^"%#{r}%")
      )

  defp maybe_filter_province(query, nil), do: query
  defp maybe_filter_province(query, ""), do: query
  defp maybe_filter_province(query, v), do: where(query, [p], p.province == ^v)
  defp maybe_filter_city(query, nil), do: query
  defp maybe_filter_city(query, ""), do: query
  defp maybe_filter_city(query, v), do: where(query, [p], ilike(p.city, ^"%#{v}%"))

  def get_skilled_profile!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:user, :skill_category, :availability_slots])
    Repo.get!(SkilledProfile, id) |> Repo.preload(preloads)
  end

  def get_skilled_profile_by_user_id(user_id) do
    case Repo.get_by(SkilledProfile, user_id: user_id) do
      nil ->
        nil

      profile ->
        Repo.preload(profile, [:skill_category, :availability_slots, :user])
    end
  end

  def create_skilled_profile(attrs) do
    %SkilledProfile{} |> SkilledProfile.full_changeset(attrs) |> Repo.insert()
  end

  def update_skilled_profile(profile, attrs) do
    profile |> SkilledProfile.full_changeset(attrs) |> Repo.update()
  end

  @doc "Lenient insert/update for seeds and migrations."
  def create_skilled_profile_seed(attrs) do
    %SkilledProfile{} |> SkilledProfile.changeset(attrs) |> Repo.insert()
  end

  def approve_skilled_profile(profile, admin_id) do
    if profile_has_pin_location?(profile.id) do
      profile
      |> Ecto.Changeset.change(%{
        status: "approved",
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second),
        approved_by_id: admin_id
      })
      |> Repo.update()
    else
      {:error, :location_required}
    end
  end

  def reject_skilled_profile(profile) do
    profile
    |> Ecto.Changeset.change(%{status: "rejected", approved_at: nil, approved_by_id: nil})
    |> Repo.update()
  end

  def freeze_profile(profile) do
    profile
    |> Ecto.Changeset.change(%{status: "frozen"})
    |> Repo.update()
  end

  def unfreeze_profile(profile) do
    profile
    |> Ecto.Changeset.change(%{status: "approved"})
    |> Repo.update()
  end

  # ── Earnings for a profile ────────────────────────────────────────────────
  def profile_earnings(profile_id) do
    import Ecto.Query
    alias SkillBridge.Payments.Payment

    case Repo.one(
           from p in Payment,
             where: p.status == "completed",
             join: b in SkillBridge.Bookings.Booking,
             on: b.id == p.booking_id,
             where: b.skilled_profile_id == ^profile_id,
             select: sum(p.amount_cents - p.platform_fee_cents)
         ) do
      nil -> 0
      v -> v
    end
  end

  # ── Availability ──────────────────────────────────────────────────────────
  def list_availability_slots(skilled_profile_id) do
    AvailabilitySlot
    |> where([s], s.skilled_profile_id == ^skilled_profile_id)
    |> order_by([s], asc: s.day_of_week, asc: s.start_time)
    |> Repo.all()
  end

  def set_availability_slots(skilled_profile_id, slots_attrs_list) do
    # Build and validate all changesets before touching the DB
    changesets =
      Enum.map(slots_attrs_list, fn attrs ->
        %AvailabilitySlot{}
        |> AvailabilitySlot.changeset(Map.put(attrs, "skilled_profile_id", skilled_profile_id))
      end)

    invalid = Enum.find(changesets, fn cs -> not cs.valid? end)

    if invalid do
      {:error, invalid}
    else
      Repo.transaction(fn ->
        Repo.delete_all(
          from s in AvailabilitySlot, where: s.skilled_profile_id == ^skilled_profile_id
        )

        inserted =
          Enum.map(changesets, fn cs ->
            case Repo.insert(cs) do
              {:ok, slot} -> slot
              {:error, err_cs} -> Repo.rollback(err_cs)
            end
          end)

        inserted
      end)
    end
  end

  def create_availability_slot(attrs) do
    %AvailabilitySlot{} |> AvailabilitySlot.changeset(attrs) |> Repo.insert()
  end

  def available_at?(skilled_profile_id, %DateTime{} = dt) do
    slots = list_availability_slots(skilled_profile_id)
    day_0_6 = day_of_week_0_sun(dt)
    time = DateTime.to_time(dt)

    Enum.any?(slots, fn slot ->
      slot.day_of_week == day_0_6 and
        Time.compare(time, slot.start_time) != :lt and
        Time.compare(time, slot.end_time) != :gt
    end)
  end

  def available_at?(_id, _), do: false

  def profile_completion(nil) do
    items = %{
      photo: false,
      personal: false,
      skill_category: false,
      bio: false,
      rate: false,
      city: false,
      location_pin: false,
      availability: false
    }

    %{completed: 0, total: map_size(items), percent: 0, items: items}
  end

  def profile_completion(profile) do
    has_location_pin = profile_has_pin_location?(profile.id)
    has_availability = list_availability_slots(profile.id) != []
    user = Repo.get!(User, profile.user_id)

    personal_ok =
      user.age &&
        is_binary(user.phone) &&
        String.match?(user.phone, ~r/^03[0-9]{9}$/) &&
        is_binary(user.gender) &&
        user.gender != "" &&
        is_binary(user.education_level) &&
        user.education_level != ""

    items = %{
      photo: is_binary(profile.profile_image_url) and profile.profile_image_url != "",
      personal: personal_ok == true,
      skill_category: not is_nil(profile.skill_category_id),
      bio: is_binary(profile.bio) and String.trim(profile.bio) != "",
      rate: is_integer(profile.hourly_rate_cents) and profile.hourly_rate_cents > 0,
      city: is_binary(profile.city) and String.trim(profile.city) != "",
      location_pin: has_location_pin,
      availability: has_availability
    }

    total = map_size(items)
    completed = Enum.count(items, fn {_k, done} -> done end)
    percent = round(completed / total * 100)

    %{completed: completed, total: total, percent: percent, items: items}
  end

  defp day_of_week_0_sun(dt) do
    # Date.day_of_week returns 1=Mon..7=Sun, we want 0=Sun..6=Sat
    date = DateTime.to_date(dt)
    # 1=Mon, 7=Sun
    dow = Date.day_of_week(date)
    # 1=Mon->1, 2=Tue->2, ..., 7=Sun->0
    rem(dow, 7)
  end

  defp profile_has_pin_location?(profile_id) do
    WorkerLocation
    |> where([w], w.skilled_profile_id == ^profile_id)
    |> where([w], not is_nil(w.latitude) and not is_nil(w.longitude))
    |> select([w], w.id)
    |> Repo.one()
    |> is_integer()
  end
end
