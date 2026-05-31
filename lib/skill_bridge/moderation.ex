defmodule SkillBridge.Moderation do
  @moduledoc """
  Admin moderation actions: freeze/unfreeze accounts, manage complaints,
  manage reviews, and verify the admin secret key.
  """
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Accounts.User
  alias SkillBridge.Moderation.{Complaint, Review, AdminSecret}

  # ── Admin Secret Key ───────────────────────────────────────────────────────

  @doc "Returns true if plain_key matches the stored admin secret key hash."
  def verify_admin_key(plain_key) when is_binary(plain_key) do
    case Repo.one(from s in AdminSecret, limit: 1) do
      nil -> false
      secret -> AdminSecret.verify(plain_key, secret)
    end
  end

  @doc "Sets (or replaces) the admin secret key. Called from seeds / mix task."
  def set_admin_key(plain_key) do
    existing = Repo.one(from s in AdminSecret, limit: 1)

    case existing do
      nil ->
        %AdminSecret{}
        |> AdminSecret.changeset(%{key: plain_key, label: "primary"})
        |> Repo.insert()

      rec ->
        rec
        |> AdminSecret.changeset(%{key: plain_key})
        |> Repo.update()
    end
  end

  # ── Freeze / Unfreeze ─────────────────────────────────────────────────────

  def freeze_user(user, admin_id) do
    user
    |> Ecto.Changeset.change(%{
      frozen_at: DateTime.utc_now() |> DateTime.truncate(:second),
      frozen_by_id: admin_id
    })
    |> Repo.update()
  end

  def unfreeze_user(user) do
    user
    |> Ecto.Changeset.change(%{frozen_at: nil, frozen_by_id: nil})
    |> Repo.update()
  end

  def frozen?(%User{frozen_at: nil}), do: false
  def frozen?(%User{frozen_at: _}), do: true

  def list_frozen_users do
    User
    |> where([u], not is_nil(u.frozen_at))
    |> order_by([u], desc: u.frozen_at)
    |> Repo.all()
  end

  # ── Complaints ─────────────────────────────────────────────────────────────

  def list_complaints_for_profile(skilled_profile_id) do
    Complaint
    |> where([c], c.skilled_profile_id == ^skilled_profile_id)
    |> preload([:user])
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def list_all_complaints do
    Complaint
    |> preload([:user, skilled_profile: [:user]])
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def create_complaint(attrs) do
    %Complaint{}
    |> Complaint.changeset(attrs)
    |> Repo.insert()
  end

  def resolve_complaint(complaint) do
    complaint
    |> Ecto.Changeset.change(%{status: "resolved"})
    |> Repo.update()
  end

  def reopen_complaint(complaint) do
    complaint
    |> Ecto.Changeset.change(%{status: "open"})
    |> Repo.update()
  end

  def get_complaint!(id), do: Repo.get!(Complaint, id) |> Repo.preload([:user, :skilled_profile])

  def count_open_complaints_for_profile(skilled_profile_id) do
    Complaint
    |> where([c], c.skilled_profile_id == ^skilled_profile_id and c.status == "open")
    |> Repo.aggregate(:count, :id)
  end

  # ── Reviews ────────────────────────────────────────────────────────────────

  def list_reviews_for_profile(skilled_profile_id) do
    Review
    |> where([r], r.skilled_profile_id == ^skilled_profile_id)
    |> preload([:user])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def average_rating_for_profile(skilled_profile_id) do
    Review
    |> where([r], r.skilled_profile_id == ^skilled_profile_id)
    |> Repo.aggregate(:avg, :rating)
    |> case do
      nil -> nil
      d -> Decimal.to_float(d) |> Float.round(1)
    end
  end

  def review_count_for_profile(skilled_profile_id) do
    Review
    |> where([r], r.skilled_profile_id == ^skilled_profile_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns `%{profile_id => %{avg: float | nil, count: integer}}` for browse cards.
  """
  def review_stats_for_profiles([]), do: %{}

  def review_stats_for_profiles(profile_ids) when is_list(profile_ids) do
    Review
    |> where([r], r.skilled_profile_id in ^profile_ids)
    |> group_by([r], r.skilled_profile_id)
    |> select([r], {r.skilled_profile_id, avg(r.rating), count(r.id)})
    |> Repo.all()
    |> Map.new(fn {id, avg, count} ->
      avg_float =
        case avg do
          nil -> nil
          %Decimal{} = d -> Decimal.to_float(d) |> Float.round(1)
          n when is_number(n) -> Float.round(n * 1.0, 1)
        end

      {id, %{avg: avg_float, count: count}}
    end)
  end

  def create_review(attrs) do
    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Only the booking client may review after the booking is completed."
  def create_review_for_booking(%SkillBridge.Bookings.Booking{} = booking, %User{} = user, attrs) do
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    cond do
      booking.user_id != user.id ->
        {:error, :unauthorized}

      booking.status != "completed" ->
        {:error, :booking_not_completed}

      true ->
        create_review(attrs)
    end
  end

  @doc "Clients may file complaints for confirmed or completed bookings."
  def create_complaint_for_booking(
        %SkillBridge.Bookings.Booking{} = booking,
        %User{} = user,
        attrs
      ) do
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    cond do
      booking.user_id != user.id ->
        {:error, :unauthorized}

      booking.status not in ["confirmed", "completed"] ->
        {:error, :booking_not_eligible}

      true ->
        create_complaint(attrs)
    end
  end

  def get_review!(id), do: Repo.get!(Review, id) |> Repo.preload([:user, :skilled_profile])
end
