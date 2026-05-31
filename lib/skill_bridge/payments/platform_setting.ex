defmodule SkillBridge.Payments.PlatformSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "platform_settings" do
    field :platform_fee_type, :string, default: "percentage"
    field :platform_fee_value, :integer, default: 10
    field :label, :string, default: "primary"
    field :bank_name, :string
    field :bank_account_title, :string
    field :bank_account_number, :string
    field :jazzcash_number, :string
    field :easypaisa_number, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [
      :platform_fee_type,
      :platform_fee_value,
      :bank_name,
      :bank_account_title,
      :bank_account_number,
      :jazzcash_number,
      :easypaisa_number
    ])
    |> validate_inclusion(:platform_fee_type, ~w(percentage fixed))
    |> validate_number(:platform_fee_value, greater_than_or_equal_to: 0)
  end
end
