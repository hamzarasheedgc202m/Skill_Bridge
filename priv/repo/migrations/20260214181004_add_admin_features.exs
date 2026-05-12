defmodule SkillBridge.Repo.Migrations.AddAdminFeatures do
  use Ecto.Migration

  def change do
    # ── Freeze account columns on users ──────────────────────────────────────
    alter table(:users) do
      add :frozen_at, :utc_datetime, null: true
      add :frozen_by_id, references(:users, on_delete: :nilify_all), null: true
    end

    # ── Admin secret key hash (one row, stored hashed) ────────────────────────
    create table(:admin_secrets) do
      add :key_hash, :string, null: false
      add :label, :string, null: false, default: "primary"
      timestamps(type: :utc_datetime)
    end

    # ── Complaints ────────────────────────────────────────────────────────────
    # A user files a complaint against a skilled person
    create table(:complaints) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :skilled_profile_id, references(:skilled_profiles, on_delete: :delete_all), null: false
      add :body, :text, null: false
      # open | resolved
      add :status, :string, null: false, default: "open"
      timestamps(type: :utc_datetime)
    end

    create index(:complaints, [:skilled_profile_id])
    create index(:complaints, [:user_id])

    # ── Reviews / feedback ────────────────────────────────────────────────────
    create table(:reviews) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :skilled_profile_id, references(:skilled_profiles, on_delete: :delete_all), null: false
      # 1-5
      add :rating, :integer, null: false
      add :body, :text
      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:skilled_profile_id])
    create index(:reviews, [:user_id])
    # One review per user per skilled profile
    create unique_index(:reviews, [:user_id, :skilled_profile_id])
  end
end
