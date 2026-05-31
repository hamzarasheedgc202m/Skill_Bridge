defmodule SkillBridge.Repo.Migrations.AddPaymentDetailsToPlatformSettings do
  use Ecto.Migration

  def change do
    alter table(:platform_settings) do
      add :bank_name, :string
      add :bank_account_title, :string
      add :bank_account_number, :string
      add :jazzcash_number, :string
      add :easypaisa_number, :string
    end
  end
end
