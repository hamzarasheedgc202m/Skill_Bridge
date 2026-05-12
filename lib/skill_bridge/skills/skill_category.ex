defmodule SkillBridge.Skills.SkillCategory do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "skill_categories" do
    field :name, :string
    field :slug, :string

    has_many :skilled_profiles, SkillBridge.Skills.SkilledProfile

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
