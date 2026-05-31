defmodule SkillBridge.Bookings do
  @moduledoc """
  Context for bookings (user hires skilled person).
  """
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Bookings.Booking
  alias SkillBridge.Payments
  alias SkillBridge.Skills
  alias SkillBridge.Skills.SkilledProfile
  alias SkillBridge.Mailer
  alias SkillBridge.Emails.BookingEmails

  def list_all_bookings do
    Booking
    |> preload([:user, skilled_profile: [:user, :skill_category]])
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
  end

  def list_bookings_for_user(user_id) do
    Booking
    |> where([b], b.user_id == ^user_id)
    |> preload([:skilled_profile, skilled_profile: [:user, :skill_category]])
    |> order_by([b], desc: b.scheduled_at)
    |> Repo.all()
  end

  def list_bookings_for_skilled_profile(skilled_profile_id) do
    Booking
    |> where([b], b.skilled_profile_id == ^skilled_profile_id)
    |> preload([:user, skilled_profile: [:skill_category]])
    |> order_by([b], desc: b.scheduled_at)
    |> Repo.all()
  end

  def get_booking!(id),
    do: Repo.get!(Booking, id) |> Repo.preload([:user, skilled_profile: [:user, :skill_category]])

  def create_booking(attrs) do
    scheduled_at = get_scheduled_at(attrs)
    profile_id = attrs["skilled_profile_id"] || attrs[:skilled_profile_id]

    cond do
      scheduled_at == nil ->
        changeset = %Booking{} |> Booking.changeset(attrs)
        {:error, changeset}

      DateTime.compare(scheduled_at, DateTime.utc_now()) != :gt ->
        {:error, :past_datetime}

      profile_id != nil and not Skills.available_at?(profile_id, scheduled_at) ->
        {:error, :not_available}

      profile_id != nil and slot_taken?(profile_id, scheduled_at) ->
        {:error, :slot_taken}

      true ->
        result =
          %Booking{}
          |> Booking.changeset(attrs)
          |> Repo.insert()

        case result do
          {:ok, booking} ->
            booking = Repo.preload(booking, [:user, skilled_profile: [:user, :skill_category]])
            BookingEmails.booking_requested(booking) |> Mailer.deliver()
            {:ok, booking}

          err ->
            err
        end
    end
  end

  defp get_scheduled_at(attrs) do
    case attrs["scheduled_at"] || attrs[:scheduled_at] do
      %DateTime{} = dt -> dt
      _ -> nil
    end
  end

  @doc """
  Returns true if another non-cancelled booking already uses this slot.
  """
  def slot_taken?(skilled_profile_id, %DateTime{} = scheduled_at) do
    Booking
    |> where(
      [b],
      b.skilled_profile_id == ^skilled_profile_id and b.scheduled_at == ^scheduled_at and
        b.status not in ["cancelled"]
    )
    |> Repo.exists?()
  end

  def slot_taken?(_, _), do: false

  def confirm_booking(booking) do
    if booking.status != "pending" do
      {:error, :invalid_status}
    else
      case update_booking(booking, %{status: "confirmed"}) do
        {:ok, updated} ->
          updated = Repo.preload(updated, [:user, skilled_profile: [:user, :skill_category]])
          BookingEmails.booking_confirmed(updated) |> Mailer.deliver()
          {:ok, updated}

        err ->
          err
      end
    end
  end

  def complete_booking(booking) do
    if booking.status != "confirmed" do
      {:error, :invalid_status}
    else
      case update_booking(booking, %{status: "completed"}) do
        {:ok, updated} ->
          updated = Repo.preload(updated, [:user, skilled_profile: [:user, :skill_category]])
          BookingEmails.booking_completed(updated) |> Mailer.deliver()
          {:ok, updated}

        err ->
          err
      end
    end
  end

  def cancel_booking(booking, cancelled_by) when cancelled_by in [:user, :skilled_person] do
    if booking.status in ["completed", "cancelled"] do
      {:error, :invalid_status}
    else
      case update_booking(booking, %{status: "cancelled"}) do
        {:ok, updated} ->
          updated = Repo.preload(updated, [:user, skilled_profile: [:user, :skill_category]])
          BookingEmails.booking_cancelled(updated, cancelled_by) |> Mailer.deliver()

          # Auto-refund any completed payment for this booking
          require Logger

          case Payments.refund_payment_for_booking(updated.id) do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              Logger.warning("Auto-refund failed for booking #{updated.id}: #{inspect(reason)}")
          end

          {:ok, updated}

        err ->
          err
      end
    end
  end

  def update_booking(booking, attrs) do
    booking
    |> Booking.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  True if the user is the booking client or the linked skilled professional.
  """
  def booking_location_participant?(booking_id, user_id)
      when is_integer(booking_id) and is_integer(user_id) do
    case Repo.get(Booking, booking_id) do
      nil ->
        false

      booking ->
        booking.user_id == user_id ||
          case Repo.get(SkilledProfile, booking.skilled_profile_id) do
            %{user_id: ^user_id} -> true
            _ -> false
          end
    end
  end

  def booking_location_role(booking_id, user_id)
      when is_integer(booking_id) and is_integer(user_id) do
    case Repo.get(Booking, booking_id) do
      nil ->
        {:error, :not_found}

      %{user_id: ^user_id} ->
        {:ok, "client"}

      booking ->
        case Repo.get(SkilledProfile, booking.skilled_profile_id) do
          %{user_id: ^user_id} -> {:ok, "professional"}
          _ -> {:error, :forbidden}
        end
    end
  end

  def booking_open_for_location?(booking_id) when is_integer(booking_id) do
    case Repo.get(Booking, booking_id) do
      %{status: status} when status in ["pending", "confirmed"] -> true
      _ -> false
    end
  end
end
