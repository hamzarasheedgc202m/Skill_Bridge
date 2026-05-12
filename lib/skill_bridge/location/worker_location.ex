defmodule SkillBridge.Location.WorkerLocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "worker_locations" do
    field :latitude, :float
    field :longitude, :float
    field :is_sharing, :boolean, default: false
    field :last_seen_at, :utc_datetime
    belongs_to :skilled_profile, SkillBridge.Skills.SkilledProfile
    timestamps(type: :utc_datetime)
  end

  def changeset(loc, attrs) do
    loc
    |> cast(attrs, [:latitude, :longitude, :is_sharing, :last_seen_at, :skilled_profile_id])
    |> validate_required([:skilled_profile_id])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> foreign_key_constraint(:skilled_profile_id)
  end
end
