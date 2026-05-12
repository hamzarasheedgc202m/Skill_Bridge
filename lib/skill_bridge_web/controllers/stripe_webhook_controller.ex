defmodule SkillBridgeWeb.StripeWebhookController do
  use SkillBridgeWeb, :controller

  alias SkillBridge.Payments

  @doc """
  Stripe sends checkout.session.completed (and others). Raw body must be verified
  before JSON decode so the signature matches Stripe's payload.
  """
  def create(conn, _params) do
    {:ok, body_raw, conn} = read_body(conn)
    sig = List.first(get_req_header(conn, "stripe-signature"))

    with :ok <- SkillBridge.Stripe.verify_webhook_signature(body_raw, sig) do
      case Jason.decode(body_raw) do
        {:ok, event} ->
          _ = dispatch_event(event)
          send_resp(conn, 200, "")

        {:error, _} ->
          conn |> put_status(400) |> text("invalid_json")
      end
    else
      {:error, reason} ->
        conn
        |> put_status(400)
        |> text("webhook_error: #{inspect(reason)}")
    end
  end

  defp dispatch_event(%{"type" => "checkout.session.completed", "data" => %{"object" => session}}) do
    case Payments.sync_payment_from_checkout_session(session) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp dispatch_event(_event), do: :ok
end
