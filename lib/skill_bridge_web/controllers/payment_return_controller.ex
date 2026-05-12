defmodule SkillBridgeWeb.PaymentReturnController do
  use SkillBridgeWeb, :controller

  alias SkillBridge.{Bookings, Payments, Stripe}

  def show(conn, %{"booking_id" => bid} = params) do
    sid = params["session_id"]
    user = conn.assigns.current_user
    booking = Bookings.get_booking!(bid)

    if sid in [nil, ""] do
      conn
      |> put_flash(:error, "Missing checkout session.")
      |> redirect(to: ~p"/user/pay/#{bid}")
    else
      show_checkout(conn, booking, user, bid, sid)
    end
  end

  defp show_checkout(conn, booking, user, bid, sid) do
    if booking.user_id != user.id do
      conn
      |> put_flash(:error, "Access denied.")
      |> redirect(to: ~p"/user")
    else
      case Stripe.retrieve_checkout_session(sid) do
        {:ok, session} ->
          if session["payment_status"] == "paid" do
            _ = Payments.sync_payment_from_checkout_session(session)

            conn
            |> put_flash(:info, "Payment confirmed. Thank you!")
            |> redirect(to: ~p"/user/pay/#{bid}")
          else
            conn
            |> put_flash(
              :error,
              "Payment not completed yet. If you were charged, status will update shortly."
            )
            |> redirect(to: ~p"/user/pay/#{bid}")
          end

        {:error, _} ->
          conn
          |> put_flash(:error, "Could not verify payment with Stripe.")
          |> redirect(to: ~p"/user/pay/#{bid}")
      end
    end
  end
end
