defmodule SkillBridge.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :body, :string
    field :kind, :string, default: "text"
    belongs_to :booking, SkillBridge.Bookings.Booking
    belongs_to :sender, SkillBridge.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(msg, attrs) do
    msg
    |> cast(attrs, [:body, :kind, :booking_id, :sender_id])
    |> validate_required([:body, :booking_id, :sender_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> validate_inclusion(:kind, ~w(text call_request))
    |> foreign_key_constraint(:booking_id)
    |> foreign_key_constraint(:sender_id)
  end
end
