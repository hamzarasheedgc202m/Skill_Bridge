defmodule SkillBridge.Repo.Migrations.AddStripeAndGatewayToPayments do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :gateway, :string, null: false, default: "internal"
      add :stripe_checkout_session_id, :string
      add :stripe_payment_intent_id, :string
    end

    create index(:payments, [:stripe_checkout_session_id])
  end
end
