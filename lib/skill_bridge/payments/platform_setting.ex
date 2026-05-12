defmodule SkillBridge.Payments.PlatformSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "platform_settings" do
    field :platform_fee_type, :string, default: "percentage"
    field :platform_fee_value, :integer, default: 10
    field :label, :string, default: "primary"
    timestamps(type: :utc_datetime)
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:platform_fee_type, :platform_fee_value])
    |> validate_inclusion(:platform_fee_type, ~w(percentage fixed))
    |> validate_number(:platform_fee_value, greater_than_or_equal_to: 0)
  end
end
