defmodule SkillBridgeWeb.UserBookingsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "user_bookings_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings
  alias SkillBridge.Moderation
  alias SkillBridge.Chat
  alias SkillBridge.Payments

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    bookings = Bookings.list_bookings_for_user(user.id)
    booking_ids = Enum.map(bookings, & &1.id)
    payment_statuses = Payments.payment_status_by_booking_ids(booking_ids)
    Enum.each(booking_ids, &Chat.subscribe/1)
    unread = Chat.unread_counts_for_bookings(booking_ids, user.id)

    {:ok,
     socket
     |> assign(:page_title, "My Bookings")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:bookings, bookings)
     |> assign(:payment_statuses, payment_statuses)
     |> assign(:unread_counts, unread)
     |> assign(:review_booking_id, nil)
     |> assign(:review_rating, 5)
     |> assign(:review_body, "")
     |> assign(:complaint_booking_id, nil)
     |> assign(:complaint_body, "")}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    # Increment unread badge if not sent by current user
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
  def handle_event("cancel", %{"id" => id}, socket) do
    booking = Bookings.get_booking!(id)

    case Bookings.cancel_booking(booking, :user) do
      {:ok, _} ->
        bookings = Bookings.list_bookings_for_user(socket.assigns.current_user.id)

        {:noreply,
         socket |> put_flash(:info, "Booking cancelled.") |> assign(:bookings, bookings)}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, "This booking can no longer be cancelled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not cancel booking.")}
    end
  end

  # ── Review handlers ────────────────────────────────────────────────

  def handle_event("open_review", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:review_booking_id, String.to_integer(id))
     |> assign(:review_rating, 5)
     |> assign(:review_body, "")
     |> assign(:complaint_booking_id, nil)}
  end

  def handle_event("close_review", _, socket),
    do: {:noreply, assign(socket, :review_booking_id, nil)}

  def handle_event("set_review_rating", %{"rating" => r}, socket),
    do: {:noreply, assign(socket, :review_rating, String.to_integer(r))}

  def handle_event("set_review_body", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :review_body, v)}

  def handle_event("submit_review", _, socket) do
    booking = Enum.find(socket.assigns.bookings, &(&1.id == socket.assigns.review_booking_id))

    attrs = %{
      "rating" => socket.assigns.review_rating,
      "body" => String.trim(socket.assigns.review_body),
      "user_id" => socket.assigns.current_user.id,
      "skilled_profile_id" => booking.skilled_profile_id
    }

    case Moderation.create_review_for_booking(booking, socket.assigns.current_user, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:review_booking_id, nil)
         |> put_flash(:info, "Review submitted — thank you!")}

      {:error, :booking_not_completed} ->
        {:noreply,
         put_flash(socket, :error, "You can only review after the booking is completed.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Access denied.")}

      {:error, %Ecto.Changeset{errors: [user_id: _]}} ->
        {:noreply,
         socket
         |> assign(:review_booking_id, nil)
         |> put_flash(:error, "You have already reviewed this professional.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not submit review.")}
    end
  end

  # ── Complaint handlers ─────────────────────────────────────────────

  def handle_event("open_complaint", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:complaint_booking_id, String.to_integer(id))
     |> assign(:complaint_body, "")
     |> assign(:review_booking_id, nil)}
  end

  def handle_event("close_complaint", _, socket),
    do: {:noreply, assign(socket, :complaint_booking_id, nil)}

  def handle_event("set_complaint_body", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :complaint_body, v)}

  def handle_event("submit_complaint", _, socket) do
    booking = Enum.find(socket.assigns.bookings, &(&1.id == socket.assigns.complaint_booking_id))
    body = String.trim(socket.assigns.complaint_body)

    if String.length(body) < 10 do
      {:noreply, put_flash(socket, :error, "Please describe the issue (at least 10 characters).")}
    else
      attrs = %{
        "body" => body,
        "user_id" => socket.assigns.current_user.id,
        "skilled_profile_id" => booking.skilled_profile_id
      }

      case Moderation.create_complaint_for_booking(
             booking,
             socket.assigns.current_user,
             attrs
           ) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:complaint_booking_id, nil)
           |> put_flash(:info, "Complaint filed. Our team will review it.")}

        {:error, :booking_not_eligible} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Complaints can be filed for confirmed or completed bookings."
           )}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "Access denied.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not file complaint.")}
      end
    end
  end

  defp status_pill(status) do
    case status do
      "pending" -> "bg-amber-100 text-amber-700 border border-amber-200"
      "confirmed" -> "bg-emerald-100 text-emerald-700 border border-emerald-200"
      "completed" -> "bg-blue-100 text-blue-700 border border-blue-200"
      "cancelled" -> "bg-red-100 text-red-600 border border-red-200"
      _ -> "bg-gray-100 text-gray-600"
    end
  end

  defp fmt(nil), do: "—"
  defp fmt(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")

  @impl true
  def render(assigns), do: index(assigns)
end
