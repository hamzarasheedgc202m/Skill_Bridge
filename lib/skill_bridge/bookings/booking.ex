defmodule SkillBridge.Bookings.Booking do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookings" do
    field :scheduled_at, :utc_datetime
    field :status, :string
    field :address, :string
    field :notes, :string

    belongs_to :user, SkillBridge.Accounts.User
    belongs_to :skilled_profile, SkillBridge.Skills.SkilledProfile

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(pending confirmed completed cancelled)

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [:scheduled_at, :status, :address, :notes, :user_id, :skilled_profile_id])
    |> validate_required([:scheduled_at, :status, :address, :user_id, :skilled_profile_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:address, min: 5, max: 500)
    |> validate_length(:notes, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:skilled_profile_id)
  end
end
