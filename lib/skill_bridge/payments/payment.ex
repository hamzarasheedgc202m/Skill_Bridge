defmodule SkillBridge.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payments" do
    field :amount_cents, :integer
    field :platform_fee_cents, :integer, default: 0
    field :status, :string, default: "pending"
    field :payment_method, :string, default: "card"
    field :transaction_ref, :string
    field :gateway, :string, default: "internal"
    field :stripe_checkout_session_id, :string
    field :stripe_payment_intent_id, :string

    belongs_to :booking, SkillBridge.Bookings.Booking
    belongs_to :payer, SkillBridge.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @statuses ~w(pending completed refunded)
  @methods ~w(card bank wallet cash)
  @gateways ~w(internal stripe)

  def changeset(p, attrs) do
    p
    |> cast(attrs, [
      :amount_cents,
      :platform_fee_cents,
      :status,
      :payment_method,
      :transaction_ref,
      :booking_id,
      :payer_id,
      :gateway,
      :stripe_checkout_session_id,
      :stripe_payment_intent_id
    ])
    |> validate_required([:amount_cents, :booking_id, :payer_id])
    |> validate_number(:amount_cents, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:payment_method, @methods)
    |> validate_inclusion(:gateway, @gateways)
    |> foreign_key_constraint(:booking_id)
    |> foreign_key_constraint(:payer_id)
  end
end
