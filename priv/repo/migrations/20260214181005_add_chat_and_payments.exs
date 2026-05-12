defmodule SkillBridge.Repo.Migrations.AddChatAndPayments do
  use Ecto.Migration

  def change do
    # Chat messages between user and skilled person on a booking
    create table(:chat_messages) do
      add :booking_id, references(:bookings, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :body, :text, null: false
      # text | call_request
      add :kind, :string, null: false, default: "text"
      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:booking_id])

    # Payments
    create table(:payments) do
      add :booking_id, references(:bookings, on_delete: :delete_all), null: false
      add :payer_id, references(:users, on_delete: :delete_all), null: false
      add :amount_cents, :integer, null: false
      add :platform_fee_cents, :integer, null: false, default: 0
      # pending | completed | refunded
      add :status, :string, null: false, default: "pending"
      # card | bank | wallet
      add :payment_method, :string, null: false, default: "card"
      add :transaction_ref, :string
      timestamps(type: :utc_datetime)
    end

    create index(:payments, [:booking_id])
    create index(:payments, [:payer_id])

    # Platform fee settings (single row)
    create table(:platform_settings) do
      # percentage | fixed
      add :platform_fee_type, :string, null: false, default: "percentage"
      # 10% or 100 cents
      add :platform_fee_value, :integer, null: false, default: 10
      add :label, :string, null: false, default: "primary"
      timestamps(type: :utc_datetime)
    end

    # Public browse — allow unauthenticated service viewing
    # No DB change needed; handled in router
  end
end
