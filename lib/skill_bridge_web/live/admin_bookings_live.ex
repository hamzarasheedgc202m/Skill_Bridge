defmodule SkillBridgeWeb.AdminBookingsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_bookings_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    bookings = Bookings.list_all_bookings()

    {:ok,
     socket
     |> assign(:page_title, "Bookings — Admin")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:bookings, bookings)
     |> assign(:filter, "all")
     |> assign(:selected_booking, nil)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    bookings = Bookings.list_all_bookings()

    filtered =
      if status == "all",
        do: bookings,
        else: Enum.filter(bookings, &(&1.status == status))

    {:noreply,
     socket
     |> assign(:bookings, filtered)
     |> assign(:filter, status)
     |> assign(:selected_booking, nil)}
  end

  def handle_event("view_booking", %{"id" => id}, socket) do
    booking = Bookings.get_booking!(String.to_integer(id))
    {:noreply, assign(socket, :selected_booking, booking)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, :selected_booking, nil)}
  end

  def handle_event("admin_cancel", %{"id" => id}, socket) do
    booking = Bookings.get_booking!(String.to_integer(id))

    case Bookings.cancel_booking(booking, :user) do
      {:ok, _updated} ->
        bookings = Bookings.list_all_bookings()

        filtered =
          if socket.assigns.filter == "all",
            do: bookings,
            else: Enum.filter(bookings, &(&1.status == socket.assigns.filter))

        {:noreply,
         socket
         |> assign(:bookings, filtered)
         |> assign(:selected_booking, nil)
         |> put_flash(:info, "Booking ##{id} cancelled.")}

      {:error, :invalid_status} ->
        {:noreply,
         put_flash(socket, :error, "Cannot cancel a completed or already cancelled booking.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel booking.")}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp status_class("pending"), do: "bg-amber-100 text-amber-700 border border-amber-200"
  defp status_class("confirmed"), do: "bg-emerald-100 text-emerald-700 border border-emerald-200"
  defp status_class("completed"), do: "bg-blue-100 text-blue-700 border border-blue-200"
  defp status_class("cancelled"), do: "bg-red-100 text-red-600 border border-red-200"
  defp status_class(_), do: "bg-gray-100 text-gray-600"

  defp fmt_dt(nil), do: "—"
  defp fmt_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")
  defp fmt_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")
  defp fmt_dt(_), do: "—"

  @impl true
  def render(assigns), do: index(assigns)
end
