defmodule SkillBridgeWeb.PaymentLive do
  use SkillBridgeWeb, :live_view
  embed_templates "payment_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings
  alias SkillBridge.Payments
  alias SkillBridge.Stripe

  @impl true
  def mount(%{"booking_id" => booking_id}, session, socket) do
    user = fetch_user(session)
    booking = Bookings.get_booking!(booking_id)

    unless booking.user_id == user.id do
      {:ok, socket |> put_flash(:error, "Access denied.") |> push_navigate(to: "/user")}
    else
      profile = booking.skilled_profile
      setting = Payments.get_platform_setting()
      existing = Payments.list_payments_for_booking(booking.id)
      already_paid = Enum.any?(existing, &(&1.status == "completed"))
      base = if profile.hourly_rate_cents, do: profile.hourly_rate_cents, else: 0
      fee = Payments.calculate_fee(base, setting)

      mode = Application.get_env(:skill_bridge, :payments, [])[:mode] || :stripe

      {:ok,
       socket
       |> assign(:page_title, "Payment — SkillBridge")
       |> assign(:current_user, user)
       |> assign(:current_scope, user.role)
       |> assign(:booking, booking)
       |> assign(:profile, profile)
       |> assign(:setting, setting)
       |> assign(:base_amount, base)
       |> assign(:fee, fee)
       |> assign(:payment_method, "card")
       |> assign(:processing, false)
       |> assign(:paid, already_paid)
       |> assign(:manual_pending, false)
       |> assign(:pending_ref, nil)
       |> assign(:payments, existing)
       |> assign(:payments_mode, mode)
       |> assign(:stripe_ready, Stripe.configured?())}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      if params["cancelled"] == "1" do
        put_flash(socket, :error, "Checkout was cancelled.")
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_method", %{"method" => m}, socket),
    do: {:noreply, assign(socket, :payment_method, m)}

  # ── Main pay dispatcher ──────────────────────────────────────────
  def handle_event("pay", _, socket) do
    socket = assign(socket, :processing, true)
    method = socket.assigns.payment_method

    cond do
      method == "card" and socket.assigns.payments_mode == :simulated ->
        pay_simulated(socket)

      method == "card" ->
        pay_production_stripe(socket)

      method in ["cash", "bank", "wallet"] ->
        pay_manual(socket, method)

      true ->
        {:noreply, socket |> assign(:processing, false) |> put_flash(:error, "Unknown payment method.")}
    end
  end

  # ── Simulated card payment (test/demo mode) ──────────────────────
  defp pay_simulated(socket) do
    total = socket.assigns.base_amount + socket.assigns.fee

    case Payments.create_simulated_payment(%{
           "amount_cents" => total,
           "platform_fee_cents" => socket.assigns.fee,
           "booking_id" => socket.assigns.booking.id,
           "payer_id" => socket.assigns.current_user.id,
           "payment_method" => socket.assigns.payment_method
         }) do
      {:ok, _} ->
        payments = Payments.list_payments_for_booking(socket.assigns.booking.id)

        {:noreply,
         socket
         |> assign(:paid, true)
         |> assign(:processing, false)
         |> assign(:payments, payments)
         |> put_flash(:info, "Payment completed! Thank you.")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Payment failed. Please try again.")}
    end
  end

  # ── Production Stripe card flow ──────────────────────────────────
  defp pay_production_stripe(socket) do
    %{base_amount: base, fee: fee, booking: booking, current_user: user} = socket.assigns

    cond do
      base == 0 ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Nothing to pay for this booking.")}

      !Stripe.configured?() ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(
           :error,
           "Stripe is not configured. Set STRIPE_SECRET_KEY for live card payments."
         )}

      true ->
        case Payments.start_stripe_checkout(booking, user, base, fee) do
          {:ok, url} ->
            {:noreply, redirect(socket, external: url)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:processing, false)
             |> put_flash(:error, stripe_checkout_error(reason))}
        end
    end
  end

  # ── Cash / Bank / Wallet — pending manual payment ────────────────
  defp pay_manual(socket, method) do
    total = socket.assigns.base_amount + socket.assigns.fee

    case Payments.create_pending_manual_payment(%{
           "amount_cents" => total,
           "platform_fee_cents" => socket.assigns.fee,
           "booking_id" => socket.assigns.booking.id,
           "payer_id" => socket.assigns.current_user.id,
           "payment_method" => method
         }) do
      {:ok, payment} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:manual_pending, true)
         |> assign(:pending_ref, payment.transaction_ref)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Could not record payment. Please try again.")}
    end
  end

  defp stripe_checkout_error({:stripe_error, code, body}),
    do: "Stripe error (#{code}): #{inspect(body)}"

  defp stripe_checkout_error({:stripe, reason}),
    do: stripe_checkout_error(reason)

  defp stripe_checkout_error(other),
    do: "Checkout could not start. #{inspect(other)}"

  defp pkr(nil), do: "PKR 0"
  defp pkr(cents), do: "PKR #{:erlang.float_to_binary(cents / 100, decimals: 0)}"

  @impl true
  def render(assigns), do: index(assigns)
end
