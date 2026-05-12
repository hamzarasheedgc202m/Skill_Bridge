defmodule SkillBridge.Repo.Migrations.AddLatLngToSkilledProfiles do
  use Ecto.Migration

  def change do
    alter table(:skilled_profiles) do
      add :latitude, :float
      add :longitude, :float
    end
  end
end
