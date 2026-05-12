defmodule SkillBridge.Moderation.Complaint do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "complaints" do
    field :body, :string
    field :status, :string, default: "open"

    belongs_to :user, SkillBridge.Accounts.User
    belongs_to :skilled_profile, SkillBridge.Skills.SkilledProfile

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(open resolved)

  def changeset(complaint, attrs) do
    complaint
    |> cast(attrs, [:body, :status, :user_id, :skilled_profile_id])
    |> validate_required([:body, :user_id, :skilled_profile_id])
    |> validate_length(:body, min: 10, max: 2000)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:skilled_profile_id)
  end
end
