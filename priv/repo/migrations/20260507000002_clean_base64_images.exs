defmodule SkillBridge.Repo.Migrations.CleanBase64Images do
  @moduledoc """
  Clears any base64 data-URLs that were previously stored in profile_image_url
  and profile_image_path columns. After this migration, these columns only hold
  short file paths ("/uploads/profiles/...") or https:// URLs.

  Affected rows will have their image field set to NULL so the user is prompted
  to re-upload their photo — much better than storing megabytes of base64 in a
  text column.
  """
  use Ecto.Migration

  def up do
    # Clear base64 data-URLs from skilled_profiles
    execute """
    UPDATE skilled_profiles
    SET profile_image_url = NULL
    WHERE profile_image_url LIKE 'data:%'
    """

    # Clear base64 data-URLs from users
    execute """
    UPDATE users
    SET profile_image_path = NULL
    WHERE profile_image_path LIKE 'data:%'
    """

    # Also tighten the column — 500 chars is plenty for a path or https URL
    alter table(:skilled_profiles) do
      modify :profile_image_url, :string, size: 500
    end

    alter table(:users) do
      modify :profile_image_path, :string, size: 500
    end
  end

  def down do
    alter table(:skilled_profiles) do
      modify :profile_image_url, :string, size: 50_000
    end

    alter table(:users) do
      modify :profile_image_path, :string, size: 50_000
    end
  end
end
