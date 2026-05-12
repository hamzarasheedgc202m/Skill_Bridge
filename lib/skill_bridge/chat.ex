defmodule SkillBridge.Chat do
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Chat.Message

  def list_messages(booking_id) do
    Message
    |> where([m], m.booking_id == ^booking_id)
    |> preload([:sender])
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def subscribe(booking_id) do
    Phoenix.PubSub.subscribe(SkillBridge.PubSub, "booking:#{booking_id}:chat")
  end

  def broadcast_message(booking_id, message) do
    Phoenix.PubSub.broadcast(
      SkillBridge.PubSub,
      "booking:#{booking_id}:chat",
      {:new_message, message}
    )
  end

  @doc "Count unread messages in a booking for a given viewer."
  def unread_count(booking_id, viewer_user_id, since \\ nil) do
    query =
      Message
      |> where([m], m.booking_id == ^booking_id)
      |> where([m], m.sender_id != ^viewer_user_id)

    query =
      if since,
        do: where(query, [m], m.inserted_at > ^since),
        else: query

    Repo.aggregate(query, :count)
  end

  @doc "Returns a map of %{booking_id => unread_count} for multiple bookings."
  def unread_counts_for_bookings(booking_ids, viewer_user_id) do
    Message
    |> where([m], m.booking_id in ^booking_ids)
    |> where([m], m.sender_id != ^viewer_user_id)
    |> group_by([m], m.booking_id)
    |> select([m], {m.booking_id, count(m.id)})
    |> Repo.all()
    |> Map.new()
  end
end
