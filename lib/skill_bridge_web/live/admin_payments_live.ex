defmodule SkillBridgeWeb.AdminPaymentsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_payments_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Payments

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)

    {:ok,
     socket
     |> assign(:page_title, "Payments")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:revenue, Payments.platform_revenue())
     |> assign(:volume, Payments.total_volume())
     |> assign(:payments, Payments.list_all_payments())
     |> assign(:filter_status, "all")}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  def handle_event("refund", %{"id" => id}, socket) do
    payment = Payments.get_payment!(String.to_integer(id))

    case Payments.refund_payment(payment) do
      {:ok, _} ->
        payments = Payments.list_all_payments()

        {:noreply,
         socket
         |> assign(:payments, payments)
         |> assign(:revenue, Payments.platform_revenue())
         |> assign(:volume, Payments.total_volume())
         |> put_flash(:info, "Payment #\#{id} refunded successfully.")}

      {:error, :already_refunded} ->
        {:noreply, put_flash(socket, :error, "This payment has already been refunded.")}

      {:error, {:stripe_error, _status, body}} ->
        _msg = get_in(body, ["error", "message"])
        {:noreply, put_flash(socket, :error, "Stripe refund failed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Refund failed. Please try again.")}
    end
  end

  def handle_event("confirm_payment", %{"id" => id}, socket) do
    payment = Payments.get_payment!(String.to_integer(id))

    case Payments.confirm_cash_payment(payment) do
      {:ok, _} ->
        payments = Payments.list_all_payments()

        {:noreply,
         socket
         |> assign(:payments, payments)
         |> assign(:revenue, Payments.platform_revenue())
         |> assign(:volume, Payments.total_volume())
         |> put_flash(:info, "Payment #\#{id} confirmed as completed.")}

      {:error, :not_pending} ->
        {:noreply, put_flash(socket, :error, "This payment is not pending.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to confirm payment.")}
    end
  end

  defp visible_payments(payments, "all"), do: payments
  defp visible_payments(payments, status), do: Enum.filter(payments, &(&1.status == status))

  defp fmt_cents(nil), do: "—"
  defp fmt_cents(c), do: "PKR #{:erlang.float_to_binary(c / 100, decimals: 0)}"

  defp fmt_dt(nil), do: "—"
  defp fmt_dt(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")

  defp status_pill("completed"), do: "bg-emerald-100 text-emerald-700"
  defp status_pill("pending"), do: "bg-amber-100 text-amber-700"
  defp status_pill("refunded"), do: "bg-blue-100 text-blue-700"
  defp status_pill(_), do: "bg-gray-100 text-gray-600"

  defp method_pill("card"), do: {"💳 Card", "bg-indigo-100 text-indigo-700"}
  defp method_pill("bank"), do: {"🏦 Bank", "bg-sky-100 text-sky-700"}
  defp method_pill("wallet"), do: {"📱 Wallet", "bg-violet-100 text-violet-700"}
  defp method_pill("cash"), do: {"💵 Cash", "bg-green-100 text-green-700"}
  defp method_pill(m), do: {String.capitalize(m || "—"), "bg-gray-100 text-gray-600"}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :visible, visible_payments(assigns.payments, assigns.filter_status))
    index(assigns)
  end
end
