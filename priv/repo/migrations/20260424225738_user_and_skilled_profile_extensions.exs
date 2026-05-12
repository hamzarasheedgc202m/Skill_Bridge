defmodule SkillBridge.Repo.Migrations.UserAndSkilledProfileExtensions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :age, :integer
      add :gender, :string
      add :education_level, :string
      add :phone, :string
      add :province, :string
      add :district, :string
      add :tehsil, :string
      add :city, :string
      add :profile_image_path, :string
    end

    alter table(:skilled_profiles) do
      add :age, :integer
      add :gender, :string
      add :education_level, :string
      add :phone, :string
      modify :profile_image_url, :text, from: :string
    end
  end
end
