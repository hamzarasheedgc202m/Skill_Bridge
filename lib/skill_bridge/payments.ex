defmodule SkillBridge.Payments do
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Payments.{Payment, PlatformSetting}
  alias SkillBridge.Stripe

  def get_platform_setting do
    case Repo.one(from s in PlatformSetting, limit: 1) do
      nil -> %PlatformSetting{platform_fee_type: "percentage", platform_fee_value: 10}
      s -> s
    end
  end

  def update_platform_setting(attrs) do
    setting =
      case Repo.one(from s in PlatformSetting, limit: 1) do
        nil -> %PlatformSetting{}
        s -> s
      end

    setting |> PlatformSetting.changeset(attrs) |> Repo.insert_or_update()
  end

  def calculate_fee(amount_cents, %PlatformSetting{
        platform_fee_type: "percentage",
        platform_fee_value: pct
      }) do
    round(amount_cents * pct / 100)
  end

  def calculate_fee(_amount_cents, %PlatformSetting{
        platform_fee_type: "fixed",
        platform_fee_value: fixed
      }) do
    fixed
  end

  @doc """
  Simulated immediate payment (used in tests / demos when `:payments` mode is `:simulated`).
  """
  def create_simulated_payment(attrs) do
    setting = get_platform_setting()
    attrs = to_string_map(attrs)
    amount = int_field(attrs["amount_cents"], 0)

    fee =
      case Map.fetch(attrs, "platform_fee_cents") do
        {:ok, v} -> int_field(v, 0)
        :error -> calculate_fee(amount, setting)
      end

    ref = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    %Payment{}
    |> Payment.changeset(
      Map.merge(attrs, %{
        "platform_fee_cents" => fee,
        "transaction_ref" => "SB-#{ref}",
        "status" => "completed",
        "gateway" => "internal"
      })
    )
    |> Repo.insert()
  end

  @doc """
  Creates a pending cash/bank/wallet payment awaiting admin confirmation.
  """
  def create_pending_manual_payment(attrs) do
    attrs = to_string_map(attrs)
    amount = int_field(attrs["amount_cents"], 0)
    setting = get_platform_setting()
    fee = int_field(Map.get(attrs, "platform_fee_cents", calculate_fee(amount, setting)), 0)
    ref = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    %Payment{}
    |> Payment.changeset(
      Map.merge(attrs, %{
        "platform_fee_cents" => fee,
        "transaction_ref" => "SB-#{ref}",
        "status" => "pending",
        "gateway" => "internal"
      })
    )
    |> Repo.insert()
  end

  @doc """
  Admin confirms a pending manual (cash/bank/wallet) payment, marking it completed.
  """
  def confirm_cash_payment(%Payment{} = payment) do
    if payment.status == "pending" do
      payment
      |> Payment.changeset(%{"status" => "completed"})
      |> Repo.update()
    else
      {:error, :not_pending}
    end
  end

  defp to_string_map(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {to_string(k), v}
    end)
  end

  defp int_field(v, _default) when is_integer(v), do: v

  defp int_field(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      :error -> default
    end
  end

  defp int_field(_, default), do: default

  def create_pending_stripe_payment(attrs) do
    %Payment{}
    |> Payment.changeset(
      Map.merge(to_string_map(attrs), %{
        "status" => "pending",
        "gateway" => "stripe",
        "payment_method" => "card"
      })
    )
    |> Repo.insert()
  end

  def set_stripe_checkout_session(%Payment{} = payment, session_id) do
    payment
    |> Payment.changeset(%{"stripe_checkout_session_id" => session_id})
    |> Repo.update()
  end

  @doc """
  Starts Stripe Checkout: creates a pending payment row and returns the hosted Checkout URL.
  """
  def start_stripe_checkout(booking, payer, base_amount_cents, fee_cents) do
    total = base_amount_cents + fee_cents
    booking_id = booking.id

    base_url = SkillBridgeWeb.Endpoint.url()
    success = "#{base_url}/user/pay/#{booking_id}/stripe-return?session_id={CHECKOUT_SESSION_ID}"
    cancel = "#{base_url}/user/pay/#{booking_id}?cancelled=1"

    Repo.transaction(fn ->
      {:ok, payment} =
        create_pending_stripe_payment(%{
          amount_cents: total,
          platform_fee_cents: fee_cents,
          booking_id: booking_id,
          payer_id: payer.id
        })

      case Stripe.create_checkout_session(booking_id, payment.id, total, success, cancel) do
        {:ok, session_id, url} ->
          case set_stripe_checkout_session(payment, session_id) do
            {:ok, _} -> url
            {:error, cs} -> Repo.rollback(cs)
          end

        {:error, reason} ->
          Repo.rollback({:stripe, reason})
      end
    end)
    |> case do
      {:ok, url} -> {:ok, url}
      {:error, {:stripe, r}} -> {:error, r}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_payment_by_stripe_session(session_id) when is_binary(session_id) do
    Repo.get_by(Payment, stripe_checkout_session_id: session_id)
  end

  def sync_payment_from_checkout_session(session) when is_map(session) do
    payment_id =
      case get_in(session, ["metadata", "payment_id"]) do
        nil -> nil
        v when is_binary(v) -> String.to_integer(v)
      end

    if payment_id == nil do
      {:error, :missing_metadata}
    else
      case Repo.get(Payment, payment_id) do
        nil ->
          {:error, :not_found}

        payment ->
          ref =
            case session["payment_intent"] do
              nil -> session["id"]
              pi when is_binary(pi) -> pi
            end

          pi = session["payment_intent"]
          pi_str = if is_binary(pi), do: pi, else: nil

          if payment.status == "completed" do
            {:ok, payment}
          else
            payment
            |> Payment.changeset(%{
              "status" => "completed",
              "transaction_ref" => ref,
              "stripe_checkout_session_id" => session["id"],
              "stripe_payment_intent_id" => pi_str
            })
            |> Repo.update()
          end
      end
    end
  end

  def list_payments_for_booking(booking_id) do
    Payment
    |> where([p], p.booking_id == ^booking_id)
    |> preload([:payer])
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def get_payment!(id), do: Repo.get!(Payment, id) |> Repo.preload([:payer, :booking])

  def platform_revenue do
    Repo.aggregate(from(p in Payment, where: p.status == "completed"), :sum, :platform_fee_cents) ||
      0
  end

  def total_volume do
    Repo.aggregate(from(p in Payment, where: p.status == "completed"), :sum, :amount_cents) || 0
  end

  @doc "Total amount paid to a skilled person (completed payments on their bookings)."
  def skilled_person_earnings(skilled_profile_id) do
    alias SkillBridge.Bookings.Booking

    booking_ids_query =
      from b in Booking, where: b.skilled_profile_id == ^skilled_profile_id, select: b.id

    Repo.aggregate(
      from(p in Payment,
        where: p.status == "completed" and p.booking_id in subquery(booking_ids_query)
      ),
      :sum,
      :amount_cents
    ) || 0
  end

  # Full payment list for admin

  @doc """
  Issues a full refund for a completed Stripe payment.
  - If gateway is stripe and payment_intent exists: calls Stripe refund API
  - If gateway is internal/simulated: marks as refunded directly
  Returns {:ok, payment} or {:error, reason}
  """
  def refund_payment(%Payment{} = payment) do
    if payment.status == "refunded" do
      {:error, :already_refunded}
    else
      result =
        cond do
          payment.gateway == "stripe" and not is_nil(payment.stripe_payment_intent_id) ->
            Stripe.create_refund(payment.stripe_payment_intent_id, "requested_by_customer")

          payment.gateway == "stripe" and not is_nil(payment.stripe_checkout_session_id) ->
            # Fallback: retrieve session to get payment_intent then refund
            case Stripe.retrieve_checkout_session(payment.stripe_checkout_session_id) do
              {:ok, %{"payment_intent" => pi_id}} when is_binary(pi_id) ->
                Stripe.create_refund(pi_id, "requested_by_customer")

              _ ->
                {:error, :no_payment_intent}
            end

          true ->
            # Simulated / internal payment — just mark refunded
            {:ok, :simulated}
        end

      case result do
        {:ok, _} ->
          payment
          |> Payment.changeset(%{status: "refunded"})
          |> Repo.update()

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def refund_payment_for_booking(booking_id) do
    case list_payments_for_booking(booking_id) do
      [] ->
        {:ok, :no_payment}

      payments ->
        completed = Enum.find(payments, &(&1.status == "completed"))
        if completed, do: refund_payment(completed), else: {:ok, :no_completed_payment}
    end
  end

  def list_all_payments(limit \\ 200) do
    Payment
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload([:payer, booking: [skilled_profile: [:user, :skill_category]]])
  end

  @doc "All payments made by a specific user (payer)."
  def list_payments_for_user(user_id) do
    Payment
    |> where([p], p.payer_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end
end
