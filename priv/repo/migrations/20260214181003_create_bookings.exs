defmodule SkillBridge.Repo.Migrations.CreateBookings do
  use Ecto.Migration

  def change do
    create table(:bookings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :skilled_profile_id, references(:skilled_profiles, on_delete: :delete_all), null: false
      add :scheduled_at, :utc_datetime, null: false
      add :status, :string, null: false
      add :address, :string, null: false
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:bookings, [:user_id])
    create index(:bookings, [:skilled_profile_id])
    create index(:bookings, [:scheduled_at])
    create index(:bookings, [:status])
  end
end
