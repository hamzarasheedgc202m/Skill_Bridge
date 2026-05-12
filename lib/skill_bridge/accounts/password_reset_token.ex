defmodule SkillBridge.Accounts.PasswordResetToken do
  use Ecto.Schema
  import Ecto.Changeset

  @token_validity_hours 2

  schema "password_reset_tokens" do
    field :token, :string
    field :used_at, :utc_datetime
    belongs_to :user, SkillBridge.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:token, :user_id, :used_at])
    |> validate_required([:token, :user_id])
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end

  def valid_for_hours, do: @token_validity_hours
end
