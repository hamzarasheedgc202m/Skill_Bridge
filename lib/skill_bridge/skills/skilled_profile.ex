defmodule SkillBridge.Skills.SkilledProfile do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending approved rejected frozen)
  @education_levels SkillBridge.Accounts.User.education_levels()
  @genders SkillBridge.Accounts.User.genders()

  schema "skilled_profiles" do
    field :region, :string
    field :bio, :string
    field :hourly_rate_cents, :integer
    field :approved_at, :utc_datetime
    field :profile_image_url, :string
    field :status, :string, default: "pending"
    # Pakistan location
    field :province, :string
    field :district, :string
    field :tehsil, :string
    field :city, :string
    field :age, :integer
    field :gender, :string
    field :education_level, :string
    field :phone, :string

    belongs_to :user, SkillBridge.Accounts.User
    belongs_to :skill_category, SkillBridge.Skills.SkillCategory
    belongs_to :approved_by, SkillBridge.Accounts.User
    has_many :availability_slots, SkillBridge.Skills.AvailabilitySlot
    has_many :bookings, SkillBridge.Bookings.Booking

    timestamps(type: :utc_datetime)
  end

  @cast_fields [
    :region,
    :bio,
    :hourly_rate_cents,
    :user_id,
    :skill_category_id,
    :approved_at,
    :approved_by_id,
    :profile_image_url,
    :status,
    :province,
    :district,
    :tehsil,
    :city,
    :age,
    :gender,
    :education_level,
    :phone
  ]

  @doc """
  Lenient changeset for seeds and admin status updates.
  """
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @cast_fields)
    |> validate_required([:skill_category_id, :user_id])
    |> validate_length(:bio, max: 2000)
    |> validate_number(:hourly_rate_cents, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:skill_category_id)
  end

  @doc """
  Strict changeset for skilled dashboard profile save (all mandatory fields).
  """
  def full_changeset(profile, attrs) do
    profile
    |> cast(attrs, @cast_fields)
    |> validate_required([
      :skill_category_id,
      :user_id,
      :profile_image_url,
      :bio,
      :hourly_rate_cents,
      :province,
      :district,
      :city,
      :age,
      :gender,
      :education_level,
      :phone
    ])
    |> validate_length(:bio, min: 10, max: 2000)
    |> validate_number(:hourly_rate_cents, greater_than: 0)
    |> validate_number(:age, greater_than_or_equal_to: 13, less_than_or_equal_to: 120)
    |> validate_inclusion(:gender, @genders)
    |> validate_inclusion(:education_level, @education_levels)
    |> validate_format(:phone, ~r/^03[0-9]{9}$/,
      message: "must be a valid Pakistan mobile number (03XXXXXXXXX)"
    )
    |> validate_length(:profile_image_url, min: 1, max: 500)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:skill_category_id)
  end

  def approved?(%__MODULE__{approved_at: nil}), do: false
  def approved?(%__MODULE__{approved_at: _}), do: true

  def status_label("pending"), do: "⏳ Pending Review"
  def status_label("approved"), do: "✅ Approved"
  def status_label("rejected"), do: "❌ Rejected"
  def status_label("frozen"), do: "🚫 Frozen"
  def status_label(_), do: "⏳ Pending Review"

  def status_color("pending"), do: "#D97706"
  def status_color("approved"), do: "#065F46"
  def status_color("rejected"), do: "#991B1B"
  def status_color("frozen"), do: "#1E40AF"
  def status_color(_), do: "#D97706"

  def status_bg("pending"), do: "#FFFBEB"
  def status_bg("approved"), do: "#F0FDF4"
  def status_bg("rejected"), do: "#FEF2F2"
  def status_bg("frozen"), do: "#EFF6FF"
  def status_bg(_), do: "#FFFBEB"
end
