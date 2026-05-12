defmodule SkillBridge.Repo.Migrations.CreateSkillCategories do
  use Ecto.Migration

  def change do
    create table(:skill_categories) do
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:skill_categories, [:slug])
  end
end
