defmodule SkillBridge.Repo.Migrations.AddProfileImageData do
  use Ecto.Migration

  def change do
    alter table(:skilled_profiles) do
      # base64 stored image (max 5MB)
      add :profile_image_data, :text, null: true
    end

    # Live location tracking
    create table(:worker_locations) do
      add :skilled_profile_id, references(:skilled_profiles, on_delete: :delete_all), null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :is_sharing, :boolean, default: false
      add :last_seen_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:worker_locations, [:skilled_profile_id])
    create index(:worker_locations, [:is_sharing])
  end
end
