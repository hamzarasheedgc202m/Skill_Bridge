defmodule SkillBridge.Moderation.AdminSecret do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_secrets" do
    field :key_hash, :string
    field :label, :string, default: "primary"
    field :key, :string, virtual: true, redact: true
    timestamps(type: :utc_datetime)
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:label, :key])
    |> validate_required([:key])
    |> validate_length(:key, min: 8)
    |> put_key_hash()
  end

  defp put_key_hash(changeset) do
    case get_change(changeset, :key) do
      nil -> changeset
      "" -> changeset
      key -> put_change(changeset, :key_hash, Bcrypt.hash_pwd_salt(key))
    end
  end

  def verify(plain_key, %__MODULE__{key_hash: hash}) do
    Bcrypt.verify_pass(plain_key, hash)
  end
end
