defmodule SkillBridge.Repo.Migrations.CreateAvailabilitySlots do
  use Ecto.Migration

  def change do
    create table(:availability_slots) do
      add :skilled_profile_id, references(:skilled_profiles, on_delete: :delete_all), null: false
      add :day_of_week, :integer, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:availability_slots, [:skilled_profile_id])
  end
end
