defmodule SkillBridge.Repo.Migrations.CreateSkilledProfiles do
  use Ecto.Migration

  def change do
    create table(:skilled_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :skill_category_id, references(:skill_categories, on_delete: :nilify_all), null: false
      add :region, :string, null: false
      add :bio, :string
      add :hourly_rate_cents, :integer
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:skilled_profiles, [:user_id])
    create index(:skilled_profiles, [:skill_category_id])
    create index(:skilled_profiles, [:region])
    create index(:skilled_profiles, [:approved_at])
  end
end
