defmodule SkillBridge.Moderation.Review do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "reviews" do
    field :rating, :integer
    field :body, :string

    belongs_to :user, SkillBridge.Accounts.User
    belongs_to :skilled_profile, SkillBridge.Skills.SkilledProfile

    timestamps(type: :utc_datetime)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:rating, :body, :user_id, :skilled_profile_id])
    |> validate_required([:rating, :user_id, :skilled_profile_id])
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_length(:body, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:skilled_profile_id)
    |> unique_constraint([:user_id, :skilled_profile_id])
  end
end
