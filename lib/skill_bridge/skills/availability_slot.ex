defmodule SkillBridge.Skills.AvailabilitySlot do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "availability_slots" do
    field :day_of_week, :integer
    field :start_time, :time
    field :end_time, :time

    belongs_to :skilled_profile, SkillBridge.Skills.SkilledProfile

    timestamps(type: :utc_datetime)
  end

  @days 0..6

  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [:day_of_week, :start_time, :end_time, :skilled_profile_id])
    |> validate_required([:day_of_week, :start_time, :end_time, :skilled_profile_id])
    |> validate_inclusion(:day_of_week, @days)
    |> validate_time_range()
    |> foreign_key_constraint(:skilled_profile_id)
  end

  defp validate_time_range(changeset) do
    start_t = get_change(changeset, :start_time)
    end_t = get_change(changeset, :end_time)

    if start_t && end_t && Time.compare(start_t, end_t) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end

  def day_name(0), do: "Sunday"
  def day_name(1), do: "Monday"
  def day_name(2), do: "Tuesday"
  def day_name(3), do: "Wednesday"
  def day_name(4), do: "Thursday"
  def day_name(5), do: "Friday"
  def day_name(6), do: "Saturday"
  def day_name(_), do: "Unknown"
end
