defmodule SkillBridge.Stripe do
  @moduledoc """
  Stripe Checkout Session creation and webhook verification using `Req`.
  No card numbers are handled by this app — Checkout collects payment on Stripe-hosted pages.
  """
  @api_base "https://api.stripe.com/v1"

  def configured? do
    secret_key() not in [nil, ""]
  end

  def publishable_key do
    get_config(:publishable_key) || System.get_env("STRIPE_PUBLISHABLE_KEY")
  end

  def webhook_secret do
    get_config(:webhook_secret) || System.get_env("STRIPE_WEBHOOK_SECRET")
  end

  def currency do
    (get_config(:currency) || System.get_env("STRIPE_CURRENCY") || "usd")
    |> to_string()
    |> String.downcase()
  end

  @doc """
  Creates a Checkout Session. `total_cents` is in the smallest currency unit Stripe expects
  for the configured currency (e.g. cents for USD).
  """
  def create_checkout_session(booking_id, payment_id, total_cents, success_url, cancel_url)
      when is_integer(booking_id) and is_integer(payment_id) and is_integer(total_cents) do
    secret = secret_key()

    if secret in [nil, ""] do
      {:error, :not_configured}
    else
      form = [
        {"mode", "payment"},
        {"success_url", success_url},
        {"cancel_url", cancel_url},
        {"client_reference_id", "#{booking_id}-#{payment_id}"},
        {"metadata[booking_id]", to_string(booking_id)},
        {"metadata[payment_id]", to_string(payment_id)},
        {"line_items[0][quantity]", "1"},
        {"line_items[0][price_data][currency]", currency()},
        {"line_items[0][price_data][unit_amount]", Integer.to_string(total_cents)},
        {"line_items[0][price_data][product_data][name]", "SkillBridge booking ##{booking_id}"}
      ]

      case Req.post("#{@api_base}/checkout/sessions",
             form: form,
             headers: [{"Authorization", "Bearer #{secret}"}]
           ) do
        {:ok, %{status: 200, body: body}} ->
          case decode_json_body(body) do
            %{"id" => id, "url" => url} when is_binary(url) -> {:ok, id, url}
            other -> {:error, {:bad_response, other}}
          end

        {:ok, %{status: status, body: body}} ->
          {:error, {:stripe_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def retrieve_checkout_session(session_id) when is_binary(session_id) do
    secret = secret_key()

    if secret in [nil, ""] do
      {:error, :not_configured}
    else
      case Req.get("#{@api_base}/checkout/sessions/#{session_id}",
             headers: [{"Authorization", "Bearer #{secret}"}]
           ) do
        {:ok, %{status: 200, body: body}} -> {:ok, decode_json_body(body)}
        {:ok, %{status: status, body: body}} -> {:error, {:stripe_error, status, body}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Verifies `Stripe-Signature` per https://stripe.com/docs/webhooks/signatures
  """
  def verify_webhook_signature(raw_body, signature_header, tolerance_sec \\ 300)

  def verify_webhook_signature(_raw, nil, _tol), do: {:error, :missing_signature}

  def verify_webhook_signature(raw_body, signature_header, tolerance_sec)
      when is_binary(raw_body) and is_binary(signature_header) do
    secret = webhook_secret()

    if secret in [nil, ""] do
      {:error, :webhook_not_configured}
    else
      with {:ok, timestamp, signatures} <- parse_signature_header(signature_header),
           :ok <- check_timestamp(timestamp, tolerance_sec),
           expected <- :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}"),
           true <- Enum.any?(signatures, &secure_equals?(expected, &1)) do
        :ok
      else
        false -> {:error, :invalid_signature}
        {:error, _} = err -> err
      end
    end
  end

  @doc """
  Issues a full refund for a Stripe PaymentIntent.
  Returns {:ok, refund_id} or {:error, reason}.
  """
  def create_refund(payment_intent_id, reason \\ "requested_by_customer")

  def create_refund(nil, _reason), do: {:error, :no_payment_intent}

  def create_refund(payment_intent_id, reason)
      when is_binary(payment_intent_id) do
    secret = secret_key()

    if secret in [nil, ""] do
      {:error, :not_configured}
    else
      form = [
        {"payment_intent", payment_intent_id},
        {"reason", reason}
      ]

      case Req.post("#{@api_base}/refunds",
             form: form,
             headers: [{"Authorization", "Bearer #{secret}"}]
           ) do
        {:ok, %{status: 200, body: body}} ->
          case decode_json_body(body) do
            %{"id" => id} -> {:ok, id}
            other -> {:error, {:bad_response, other}}
          end

        {:ok, %{status: status, body: body}} ->
          {:error, {:stripe_error, status, decode_json_body(body)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp parse_signature_header(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    t =
      parts
      |> Enum.find_value(fn part ->
        case String.split(part, "=", parts: 2) do
          ["t", ts] -> ts
          _ -> nil
        end
      end)

    sigs =
      parts
      |> Enum.flat_map(fn part ->
        case String.split(part, "=", parts: 2) do
          ["v1", hex] -> [hex]
          _ -> []
        end
      end)

    if t && sigs != [] do
      parsed =
        Enum.map(sigs, fn hex ->
          Base.decode16!(hex, case: :lower)
        end)

      {:ok, t, parsed}
    else
      {:error, :bad_header}
    end
  rescue
    _ -> {:error, :bad_header}
  end

  defp check_timestamp(t_str, tolerance_sec) do
    case Integer.parse(t_str) do
      {ts, _} ->
        now = System.system_time(:second)

        if abs(now - ts) <= tolerance_sec do
          :ok
        else
          {:error, :timestamp_skew}
        end

      _ ->
        {:error, :bad_timestamp}
    end
  end

  defp secure_equals?(expected, got) when byte_size(expected) == byte_size(got) do
    Plug.Crypto.secure_compare(expected, got)
  end

  defp secure_equals?(_, _), do: false

  defp secret_key do
    get_config(:secret_key) || System.get_env("STRIPE_SECRET_KEY")
  end

  defp get_config(key) do
    Application.get_env(:skill_bridge, :stripe, [])[key]
  end

  defp decode_json_body(body) when is_map(body), do: body

  defp decode_json_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp decode_json_body(_), do: %{}
end
