defmodule SkillBridge.Repo.Migrations.AddProfileImageAndStatus do
  use Ecto.Migration

  def change do
    alter table(:skilled_profiles) do
      add :profile_image_url, :string, null: true
      add :status, :string, null: false, default: "pending"
      # pending | approved | rejected | frozen
    end

    # Pakistan location fields
    alter table(:skilled_profiles) do
      add :province, :string, null: true
      add :district, :string, null: true
      add :tehsil, :string, null: true
      add :city, :string, null: true
    end
  end
end
