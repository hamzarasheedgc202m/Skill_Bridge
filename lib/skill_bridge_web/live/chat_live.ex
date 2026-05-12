defmodule SkillBridgeWeb.ChatLive do
  use SkillBridgeWeb, :live_view
  embed_templates "chat_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings
  alias SkillBridge.Chat

  @impl true
  def mount(%{"booking_id" => booking_id}, session, socket) do
    user = fetch_user(session)
    booking = Bookings.get_booking!(booking_id)

    # Security: allow the booking participants OR an admin
    allowed =
      user.role == "admin" or
        booking.user_id == user.id or
        booking.skilled_profile.user_id == user.id

    unless allowed do
      {:ok, socket |> put_flash(:error, "Access denied.") |> push_navigate(to: "/")}
    else
      if connected?(socket), do: Chat.subscribe(booking.id)
      messages = Chat.list_messages(booking.id)

      {:ok,
       socket
       |> assign(:page_title, "Chat — Booking ##{booking.id}")
       |> assign(:current_user, user)
       |> assign(:current_scope, user.role)
       |> assign(:booking, booking)
       |> assign(:messages, messages)
       |> assign(:message, "")
       |> assign(:show_call_modal, false)
       |> assign(:admin_view, user.role == "admin")}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("update_message", %{"value" => msg}, socket) do
    {:noreply, assign(socket, :message, msg)}
  end

  def handle_event("send_message", _params, socket) do
    msg = String.trim(socket.assigns.message)

    if msg != "" do
      case Chat.create_message(%{
             "body" => msg,
             "kind" => "text",
             "booking_id" => socket.assigns.booking.id,
             "sender_id" => socket.assigns.current_user.id
           }) do
        {:ok, message} ->
          message = %{message | sender: socket.assigns.current_user}
          Chat.broadcast_message(socket.assigns.booking.id, message)
          {:noreply, assign(socket, :message, "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not send message.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_call", _, socket), do: {:noreply, assign(socket, :show_call_modal, true)}

  def handle_event("hide_call", _, socket),
    do: {:noreply, assign(socket, :show_call_modal, false)}

  def handle_event("request_call", _, socket) do
    case Chat.create_message(%{
           "body" => "📞 #{socket.assigns.current_user.name} is requesting a call",
           "kind" => "call_request",
           "booking_id" => socket.assigns.booking.id,
           "sender_id" => socket.assigns.current_user.id
         }) do
      {:ok, msg} ->
        msg = %{msg | sender: socket.assigns.current_user}
        Chat.broadcast_message(socket.assigns.booking.id, msg)

        {:noreply,
         socket |> assign(:show_call_modal, false) |> put_flash(:info, "Call request sent!")}

      _ ->
        {:noreply, assign(socket, :show_call_modal, false)}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, assign(socket, :messages, socket.assigns.messages ++ [message])}
  end

  defp me?(msg, user), do: msg.sender_id == user.id
  defp fmt_time(dt), do: Calendar.strftime(dt, "%H:%M")

  defp status_pill("pending"), do: "background:#FEF3C7;color:#92400E"
  defp status_pill("confirmed"), do: "background:#D1FAE5;color:#065F46"
  defp status_pill("completed"), do: "background:#DBEAFE;color:#1E40AF"
  defp status_pill("cancelled"), do: "background:#FEE2E2;color:#991B1B"
  defp status_pill(_), do: "background:#E5E7EB;color:#374151"

  @impl true
  def render(assigns), do: index(assigns)
end
