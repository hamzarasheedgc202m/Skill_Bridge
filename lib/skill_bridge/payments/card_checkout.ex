defmodule SkillBridge.Payments.CardCheckout do
  @moduledoc """
  Validates card details for simulated (dev/demo) checkout.
  Uses the same test card numbers as Stripe's documentation.
  """

  @success_cards ~w(4242424242424242 4242424242424241)
  @decline_card "4000000000000002"
  @insufficient_funds_card "4000000000009995"

  def validate(attrs) when is_map(attrs) do
    number = normalize_digits(attrs["card_number"] || attrs[:card_number])
    expiry = String.trim(to_string(attrs["expiry"] || attrs[:expiry] || ""))
    cvc = normalize_digits(attrs["cvc"] || attrs[:cvc])
    name = String.trim(to_string(attrs["cardholder_name"] || attrs[:cardholder_name] || ""))

    with :ok <- validate_number(number),
         :ok <- validate_expiry(expiry),
         :ok <- validate_cvc(cvc),
         :ok <- validate_name(name),
         :ok <- validate_card_outcome(number) do
      {:ok, %{card_last4: String.slice(number, -4, 4)}}
    end
  end

  defp validate_number(""), do: {:error, "Card number is required."}

  defp validate_number(number) when byte_size(number) < 13,
    do: {:error, "Card number is invalid."}

  defp validate_number(number) when byte_size(number) > 19,
    do: {:error, "Card number is invalid."}

  defp validate_number(number) do
    if luhn_valid?(number), do: :ok, else: {:error, "Card number is invalid."}
  end

  defp validate_expiry("") do
    {:error, "Expiry date is required (MM/YY)."}
  end

  defp validate_expiry(expiry) do
    case String.split(expiry, "/", parts: 2) do
      [mm, yy] ->
        with {month, _} <- Integer.parse(String.trim(mm)),
             {year, _} <- Integer.parse(String.trim(yy)),
             true <- month in 1..12,
             full_year <- full_year(year),
             true <- not expired?(month, full_year) do
          :ok
        else
          _ -> {:error, "Expiry date is invalid or expired."}
        end

      _ ->
        {:error, "Expiry must be MM/YY."}
    end
  end

  defp validate_cvc("") do
    {:error, "CVC is required."}
  end

  defp validate_cvc(cvc) when byte_size(cvc) in 3..4, do: :ok
  defp validate_cvc(_), do: {:error, "CVC must be 3 or 4 digits."}

  defp validate_name("") do
    {:error, "Name on card is required."}
  end

  defp validate_name(_), do: :ok

  defp validate_card_outcome(number) do
    cond do
      number in @success_cards ->
        :ok

      number == @decline_card ->
        {:error, "Your card was declined. Try another payment method."}

      number == @insufficient_funds_card ->
        {:error, "Insufficient funds on this card."}

      true ->
        {:error,
         "Use test card 4242 4242 4242 4242 in demo mode, or pay with Stripe in production."}
    end
  end

  defp normalize_digits(nil), do: ""
  defp normalize_digits(val), do: val |> to_string() |> String.replace(~r/\D/, "")

  defp full_year(yy) when yy < 100, do: 2000 + yy
  defp full_year(yy), do: yy

  defp expired?(month, year) do
    now = Date.utc_today()
    year < now.year or (year == now.year and month < now.month)
  end

  defp luhn_valid?(number) do
    digits =
      number
      |> String.graphemes()
      |> Enum.map(&String.to_integer/1)

    sum =
      digits
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(0, fn {digit, idx}, acc ->
        if rem(idx, 2) == 1 do
          d = digit * 2
          acc + if d > 9, do: d - 9, else: d
        else
          acc + digit
        end
      end)

    rem(sum, 10) == 0
  end
end
