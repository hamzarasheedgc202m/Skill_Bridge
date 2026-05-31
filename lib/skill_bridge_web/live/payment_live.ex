defmodule SkillBridgeWeb.PaymentLive do
  use SkillBridgeWeb, :live_view
  embed_templates "payment_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Bookings
  alias SkillBridge.Payments
  alias SkillBridge.Payments.CardCheckout
  alias SkillBridge.Stripe

  @impl true
  def mount(%{"booking_id" => booking_id}, session, socket) do
    user = fetch_user(session)
    booking = Bookings.get_booking!(booking_id)

    cond do
      booking.user_id != user.id ->
        {:ok, socket |> put_flash(:error, "Access denied.") |> push_navigate(to: "/user")}

      booking.status != "confirmed" ->
        {:ok,
         socket
         |> put_flash(
           :error,
           "Payment is only available after the professional confirms your booking."
         )
         |> push_navigate(to: ~p"/user/bookings")}

      true ->
        {:ok, payment_socket(socket, user, booking)}
    end
  end

  defp payment_socket(socket, user, booking) do
    profile = booking.skilled_profile
    setting = Payments.get_platform_setting()
    existing = Payments.list_payments_for_booking(booking.id)
    already_paid = Payments.booking_paid?(booking.id)
    pending = Payments.get_pending_payment_for_booking(booking.id)
    base = if profile.hourly_rate_cents, do: profile.hourly_rate_cents, else: 0
    fee = Payments.calculate_fee(base, setting)
    mode = Application.get_env(:skill_bridge, :payments, [])[:mode] || :stripe

    {manual_pending, pending_ref, payment_method} =
      case pending do
        %{} = p when p.gateway == "internal" and p.status == "pending" ->
          {true, p.transaction_ref, p.payment_method}

        _ ->
          {false, nil, "card"}
      end

    stripe_pending? = match?(%{gateway: "stripe", status: "pending"}, pending)

    socket
    |> assign(:page_title, "Payment — SkillBridge")
    |> assign(:current_user, user)
    |> assign(:current_scope, user.role)
    |> assign(:booking, booking)
    |> assign(:profile, profile)
    |> assign(:setting, setting)
    |> assign(:base_amount, base)
    |> assign(:fee, fee)
    |> assign(:payment_method, payment_method)
    |> assign(:processing, false)
    |> assign(:paid, already_paid)
    |> assign(:manual_pending, manual_pending)
    |> assign(:stripe_pending, stripe_pending?)
    |> assign(:pending_ref, pending_ref)
    |> assign(:payments, existing)
    |> assign(:payments_mode, mode)
    |> assign(:stripe_ready, Stripe.configured?())
    |> assign(:card_number, "")
    |> assign(:card_expiry, "")
    |> assign(:card_cvc, "")
    |> assign(:cardholder_name, "")
    |> assign(:card_errors, %{})
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
      cond do
        params["cancelled"] == "1" ->
          put_flash(socket, :error, "Checkout was cancelled.")

        params["session_id"] ->
          refresh_payment_state(socket)

        true ->
          socket
      end

    {:noreply, socket}
  end

  defp refresh_payment_state(socket) do
    booking = socket.assigns.booking
    existing = Payments.list_payments_for_booking(booking.id)
    pending = Payments.get_pending_payment_for_booking(booking.id)

    {manual_pending, pending_ref, payment_method} =
      case pending do
        %{} = p when p.gateway == "internal" and p.status == "pending" ->
          {true, p.transaction_ref, p.payment_method}

        _ ->
          {false, nil, socket.assigns.payment_method}
      end

    socket
    |> assign(:paid, Payments.booking_paid?(booking.id))
    |> assign(:payments, existing)
    |> assign(:manual_pending, manual_pending)
    |> assign(:stripe_pending, match?(%{gateway: "stripe", status: "pending"}, pending))
    |> assign(:pending_ref, pending_ref)
    |> assign(:payment_method, payment_method)
  end

  @impl true
  def handle_event("set_method", %{"method" => m}, socket),
    do: {:noreply, assign(socket, :payment_method, m)}

  def handle_event("validate_card", params, socket) do
    card_params = %{
      "card_number" => params["card_number"] || socket.assigns.card_number,
      "expiry" => params["expiry"] || socket.assigns.card_expiry,
      "cvc" => params["cvc"] || socket.assigns.card_cvc,
      "cardholder_name" => params["cardholder_name"] || socket.assigns.cardholder_name
    }

    {:noreply,
     socket
     |> assign(:card_number, card_params["card_number"])
     |> assign(:card_expiry, card_params["expiry"])
     |> assign(:card_cvc, card_params["cvc"])
     |> assign(:cardholder_name, card_params["cardholder_name"])
     |> assign(:card_errors, %{})}
  end

  def handle_event("pay", params, socket) do
    if socket.assigns.paid do
      {:noreply, put_flash(socket, :error, "This booking is already paid.")}
    else
      socket = assign(socket, :processing, true)
      method = socket.assigns.payment_method

      cond do
        socket.assigns.stripe_pending ->
          {:noreply,
           socket
           |> assign(:processing, false)
           |> put_flash(:error, "A card checkout is already in progress. Complete it or wait.")}

        method == "card" and socket.assigns.payments_mode == :simulated ->
          pay_simulated_card(socket, params)

        method == "card" ->
          pay_production_stripe(socket)

        method in ["cash", "bank", "wallet"] ->
          pay_manual(socket, method)

        true ->
          {:noreply,
           socket |> assign(:processing, false) |> put_flash(:error, "Unknown payment method.")}
      end
    end
  end

  defp pay_simulated_card(socket, params) do
    card_params = %{
      "card_number" => params["card_number"] || socket.assigns.card_number,
      "expiry" => params["expiry"] || socket.assigns.card_expiry,
      "cvc" => params["cvc"] || socket.assigns.card_cvc,
      "cardholder_name" => params["cardholder_name"] || socket.assigns.cardholder_name
    }

    total = socket.assigns.base_amount + socket.assigns.fee

    with {:ok, %{card_last4: last4}} <- CardCheckout.validate(card_params),
         {:ok, _} <-
           Payments.create_simulated_payment(%{
             "amount_cents" => total,
             "platform_fee_cents" => socket.assigns.fee,
             "booking_id" => socket.assigns.booking.id,
             "payer_id" => socket.assigns.current_user.id,
             "payment_method" => "card",
             "card_last4" => last4
           }) do
      payments = Payments.list_payments_for_booking(socket.assigns.booking.id)

      {:noreply,
       socket
       |> assign(:paid, true)
       |> assign(:processing, false)
       |> assign(:payments, payments)
       |> assign(:card_errors, %{})
       |> put_flash(:info, "Payment completed successfully.")}
    else
      {:error, :already_paid} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:paid, true)
         |> put_flash(:info, "This booking is already paid.")}

      {:error, message} when is_binary(message) ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:card_errors, %{"card" => message})
         |> put_flash(:error, message)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Payment failed. Please try again.")}
    end
  end

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

          {:error, :already_paid} ->
            {:noreply,
             socket
             |> assign(:processing, false)
             |> assign(:paid, true)
             |> put_flash(:info, "This booking is already paid.")}

          {:error, :payment_pending} ->
            {:noreply,
             socket
             |> assign(:processing, false)
             |> assign(:stripe_pending, true)
             |> put_flash(:error, "A payment is already pending for this booking.")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:processing, false)
             |> put_flash(:error, stripe_checkout_error(reason))}
        end
    end
  end

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
         |> assign(:pending_ref, payment.transaction_ref)
         |> assign(:payment_method, method)
         |> put_flash(
           :info,
           "Payment instructions recorded. Complete transfer or pay on arrival."
         )}

      {:error, :already_paid} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:paid, true)
         |> put_flash(:info, "This booking is already paid.")}

      {:error, :payment_pending} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "A payment is already pending for this booking.")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Could not record payment. Please try again.")}
    end
  end

  defp stripe_checkout_error({:stripe_error, code, body}),
    do: "Stripe error (#{code}): #{payment_error_message(body)}"

  defp stripe_checkout_error({:stripe, reason}),
    do: stripe_checkout_error(reason)

  defp stripe_checkout_error(:already_paid), do: "This booking is already paid."
  defp stripe_checkout_error(:payment_pending), do: "A payment is already pending."
  defp stripe_checkout_error(:zero_amount), do: "Nothing to pay for this booking."
  defp stripe_checkout_error(:not_configured), do: "Stripe is not configured."
  defp stripe_checkout_error(other), do: "Checkout could not start. #{inspect(other)}"

  defp payment_error_message(body) when is_map(body) do
    get_in(body, ["error", "message"]) || inspect(body)
  end

  defp payment_error_message(body), do: inspect(body)

  defp pkr(nil), do: "PKR 0"
  defp pkr(cents), do: "PKR #{:erlang.float_to_binary(cents / 100, decimals: 0)}"

  @impl true
  def render(assigns), do: index(assigns)
end
