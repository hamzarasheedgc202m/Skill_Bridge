defmodule SkillBridgeWeb.SkilledBookingsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "skilled_bookings_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Bookings
  alias SkillBridge.Chat

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    profile = Skills.get_skilled_profile_by_user_id(user.id)
    bookings = if profile, do: Bookings.list_bookings_for_skilled_profile(profile.id), else: []

    booking_ids = Enum.map(bookings, & &1.id)
    Enum.each(booking_ids, &Chat.subscribe/1)
    unread = Chat.unread_counts_for_bookings(booking_ids, user.id)

    {:ok,
     socket
     |> assign(:page_title, "My Bookings")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:profile, profile)
     |> assign(:bookings, bookings)
     |> assign(:unread_counts, unread)}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    if msg.sender_id != socket.assigns.current_user.id do
      unread = Map.update(socket.assigns.unread_counts, msg.booking_id, 1, &(&1 + 1))
      {:noreply, assign(socket, :unread_counts, unread)}
    else
      {:noreply, socket}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("confirm", %{"id" => id}, socket) do
    booking = Bookings.get_booking!(id)

    case Bookings.confirm_booking(booking) do
      {:ok, _} ->
        bookings = Bookings.list_bookings_for_skilled_profile(socket.assigns.profile.id)

        {:noreply,
         socket |> put_flash(:info, "Booking confirmed!") |> assign(:bookings, bookings)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not confirm.")}
    end
  end

  def handle_event("complete", %{"id" => id}, socket) do
    booking = Bookings.get_booking!(id)

    case Bookings.complete_booking(booking) do
      {:ok, _} ->
        bookings = Bookings.list_bookings_for_skilled_profile(socket.assigns.profile.id)

        {:noreply,
         socket |> put_flash(:info, "Booking marked as completed!") |> assign(:bookings, bookings)}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, "Only confirmed bookings can be completed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete booking.")}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    booking = Bookings.get_booking!(id)

    case Bookings.cancel_booking(booking, :skilled_person) do
      {:ok, _} ->
        bookings = Bookings.list_bookings_for_skilled_profile(socket.assigns.profile.id)

        {:noreply,
         socket |> put_flash(:info, "Booking cancelled.") |> assign(:bookings, bookings)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not cancel.")}
    end
  end

  defp status_pill("pending"), do: "bg-amber-100 text-amber-700 border border-amber-200"
  defp status_pill("confirmed"), do: "bg-emerald-100 text-emerald-700 border border-emerald-200"
  defp status_pill("completed"), do: "bg-blue-100 text-blue-700 border border-blue-200"
  defp status_pill("cancelled"), do: "bg-red-100 text-red-600 border border-red-200"
  defp status_pill(_), do: "bg-gray-100 text-gray-600"

  defp fmt(nil), do: "—"
  defp fmt(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")

  @impl true
  def render(assigns), do: index(assigns)
end
