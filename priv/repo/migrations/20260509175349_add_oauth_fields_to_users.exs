defmodule SkillBridge.Repo.Migrations.AddOauthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :oauth_provider, :string, null: true
      add :oauth_uid, :string, null: true
    end

    create unique_index(:users, [:oauth_provider, :oauth_uid],
             where: "oauth_uid IS NOT NULL",
             name: :users_oauth_provider_uid_index
           )
  end
end
