defmodule SkillBridge.Accounts.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :role, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true

    field :age, :integer
    field :gender, :string
    field :education_level, :string
    field :phone, :string
    field :province, :string
    field :district, :string
    field :tehsil, :string
    field :city, :string
    field :profile_image_path, :string

    field :oauth_provider, :string
    field :oauth_uid, :string

    field :frozen_at, :utc_datetime
    belongs_to :frozen_by, SkillBridge.Accounts.User, foreign_key: :frozen_by_id

    has_one :skilled_profile, SkillBridge.Skills.SkilledProfile
    has_many :bookings_as_user, SkillBridge.Bookings.Booking, foreign_key: :user_id
    has_many :bookings_approved, SkillBridge.Bookings.Booking

    timestamps(type: :utc_datetime)
  end

  @roles ~w(user skilled_person admin)
  @required [:email, :name, :role]
  @optional [:password_hash, :oauth_provider, :oauth_uid]
  @profile_fields ~w(age gender education_level phone province district tehsil city profile_image_path)a
  @education_levels ~w(none primary middle matric intermediate bachelor master phd other)
  @genders ~w(male female other prefer_not_say)

  def education_levels, do: @education_levels
  def genders, do: @genders

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required ++ @optional ++ [:password] ++ @profile_fields)
    |> validate_required(@required)
    |> validate_inclusion(:role, @roles)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:name, min: 2, max: 200)
    |> validate_number(:age, greater_than_or_equal_to: 13, less_than_or_equal_to: 120)
    |> validate_inclusion(:gender, @genders)
    |> validate_inclusion(:education_level, @education_levels)
    |> validate_pakistan_phone_optional()
    |> validate_length(:profile_image_path, max: 500)
    |> maybe_put_password_hash()
    |> unique_constraint(:email)
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name] ++ @profile_fields)
    |> validate_required([
      :name,
      :age,
      :gender,
      :education_level,
      :phone,
      :province,
      :district,
      :city,
      :profile_image_path
    ])
    |> validate_length(:name, min: 2, max: 200)
    |> validate_number(:age, greater_than_or_equal_to: 13, less_than_or_equal_to: 120)
    |> validate_inclusion(:gender, @genders)
    |> validate_inclusion(:education_level, @education_levels)
    |> validate_format(:phone, ~r/^03[0-9]{9}$/,
      message: "must be a valid Pakistan mobile number (03XXXXXXXXX)"
    )
    |> validate_length(:profile_image_path, min: 1, max: 500)
  end

  @doc "Used for Google/Supabase OAuth sign-in — no password required."
  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :oauth_provider, :oauth_uid])
    |> validate_required([:email, :name, :role, :oauth_provider, :oauth_uid])
    |> validate_inclusion(:role, @roles)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:name, min: 2, max: 200)
    |> unique_constraint(:email)
    |> unique_constraint([:oauth_provider, :oauth_uid], name: :users_oauth_provider_uid_index)
  end

  @doc "Used by password reset flow to update only the password."
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, message: "must be at least 8 characters")
    |> maybe_put_password_hash()
  end

  defp validate_pakistan_phone_optional(changeset) do
    case get_change(changeset, :phone) do
      nil ->
        changeset

      "" ->
        put_change(changeset, :phone, nil)

      phone when is_binary(phone) ->
        validate_format(changeset, :phone, ~r/^03[0-9]{9}$/,
          message: "must be a valid Pakistan mobile number (03XXXXXXXXX)"
        )

      _ ->
        changeset
    end
  end

  defp maybe_put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      "" -> changeset
      password -> change(changeset, password_hash: Bcrypt.hash_pwd_salt(password))
    end
  end
end
