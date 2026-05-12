defmodule SkillBridge.Repo.Migrations.CreatePasswordResetTokens do
  use Ecto.Migration

  def change do
    create table(:password_reset_tokens) do
      add :token, :string, null: false
      add :used_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:password_reset_tokens, [:token])
    create index(:password_reset_tokens, [:user_id])
  end
end
