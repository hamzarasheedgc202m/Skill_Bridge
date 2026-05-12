defmodule SkillBridgeWeb.UserDashboardLive do
  use SkillBridgeWeb, :live_view
  embed_templates "user_dashboard_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings
  alias SkillBridge.Payments
  alias SkillBridge.Chat

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    bookings = Bookings.list_bookings_for_user(user.id)

    pending_count = Enum.count(bookings, &(&1.status == "pending"))
    confirmed_count = Enum.count(bookings, &(&1.status == "confirmed"))
    completed_count = Enum.count(bookings, &(&1.status == "completed"))

    # Payment stats (single query)
    all_payments = Payments.list_payments_for_user(user.id)
    completed_payments = Enum.filter(all_payments, &(&1.status == "completed"))
    pending_payment_count = Enum.count(all_payments, &(&1.status == "pending"))
    total_paid_cents = Enum.sum(Enum.map(completed_payments, & &1.amount_cents))

    recent_payments =
      completed_payments
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(5)

    # Chat: unread counts per booking
    booking_ids = Enum.map(bookings, & &1.id)

    unread_map =
      if booking_ids != [],
        do: Chat.unread_counts_for_bookings(booking_ids, user.id),
        else: %{}

    chat_notifications =
      bookings
      |> Enum.filter(fn b -> Map.get(unread_map, b.id, 0) > 0 end)
      |> Enum.sort_by(fn b -> Map.get(unread_map, b.id, 0) end, :desc)

    total_unread = Enum.sum(Map.values(unread_map))

    if connected?(socket), do: :timer.send_interval(1000, :tick)

    now = pkt_now()

    {:ok,
     socket
     |> assign(:page_title, "My Dashboard")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:bookings, bookings)
     |> assign(:pending_count, pending_count)
     |> assign(:confirmed_count, confirmed_count)
     |> assign(:completed_count, completed_count)
     |> assign(:total_paid_cents, total_paid_cents)
     |> assign(:pending_payment_count, pending_payment_count)
     |> assign(:recent_payments, recent_payments)
     |> assign(:unread_map, unread_map)
     |> assign(:chat_notifications, chat_notifications)
     |> assign(:total_unread, total_unread)
     |> assign(:now, now)
     |> assign(:today_bookings, today_bookings(bookings, now))}
  end

  @impl true
  def handle_info(:tick, socket) do
    now = pkt_now()

    {:noreply,
     socket
     |> assign(:now, now)
     |> assign(:today_bookings, today_bookings(socket.assigns.bookings, now))}
  end

  defp pkt_now, do: DateTime.add(DateTime.utc_now(), 5 * 3600, :second)

  defp today_bookings(bookings, now) do
    today = DateTime.to_date(now)

    bookings
    |> Enum.filter(fn b ->
      b.scheduled_at != nil and
        DateTime.to_date(b.scheduled_at) == today and
        b.status in ["pending", "confirmed"]
    end)
    |> Enum.sort_by(& &1.scheduled_at)
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
