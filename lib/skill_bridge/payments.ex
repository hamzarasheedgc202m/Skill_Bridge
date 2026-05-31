defmodule SkillBridge.Payments do
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Payments.{Payment, PlatformSetting}
  alias SkillBridge.Stripe

  def get_platform_setting do
    case Repo.one(from s in PlatformSetting, limit: 1) do
      nil ->
        %PlatformSetting{
          platform_fee_type: "percentage",
          platform_fee_value: 10,
          bank_name: "HBL / Meezan Bank",
          bank_account_title: "SkillBridge Pvt Ltd",
          bank_account_number: "1234-5678901-234",
          jazzcash_number: "0300-1234567",
          easypaisa_number: "0333-9876543"
        }

      s ->
        s
    end
  end

  def completed_payment?(%Payment{status: "completed"}), do: true
  def completed_payment?(_), do: false

  def booking_paid?(booking_id) do
    Repo.exists?(
      from p in Payment,
        where: p.booking_id == ^booking_id and p.status == "completed"
    )
  end

  def get_pending_payment_for_booking(booking_id) do
    Payment
    |> where([p], p.booking_id == ^booking_id and p.status == "pending")
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def payment_status_by_booking_ids([]), do: %{}

  def payment_status_by_booking_ids(booking_ids) when is_list(booking_ids) do
    Payment
    |> where([p], p.booking_id in ^booking_ids)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
    |> Enum.group_by(& &1.booking_id)
    |> Map.new(fn {bid, payments} ->
      status =
        cond do
          Enum.any?(payments, &(&1.status == "completed")) -> :paid
          Enum.any?(payments, &(&1.status == "pending")) -> :pending
          true -> :unpaid
        end

      {bid, status}
    end)
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
    attrs = to_string_map(attrs)
    booking_id = int_field(attrs["booking_id"], nil)

    if booking_id && booking_paid?(booking_id) do
      {:error, :already_paid}
    else
      insert_completed_payment(attrs, gateway: "internal", ref_prefix: "SB")
    end
  end

  defp insert_completed_payment(attrs, opts) do
    setting = get_platform_setting()
    amount = int_field(attrs["amount_cents"], 0)

    fee =
      case Map.fetch(attrs, "platform_fee_cents") do
        {:ok, v} -> int_field(v, 0)
        :error -> calculate_fee(amount, setting)
      end

    ref_suffix = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    ref_prefix = Keyword.get(opts, :ref_prefix, "SB")
    last4 = Map.get(attrs, "card_last4")

    ref =
      if last4 do
        "#{ref_prefix}-#{last4}-#{ref_suffix}"
      else
        "#{ref_prefix}-#{ref_suffix}"
      end

    %Payment{}
    |> Payment.changeset(
      Map.merge(attrs, %{
        "platform_fee_cents" => fee,
        "transaction_ref" => ref,
        "status" => "completed",
        "gateway" => Keyword.get(opts, :gateway, "internal"),
        "payment_method" => Map.get(attrs, "payment_method", "card")
      })
    )
    |> Repo.insert()
  end

  @doc """
  Creates a pending cash/bank/wallet payment awaiting admin confirmation.
  """
  def create_pending_manual_payment(attrs) do
    attrs = to_string_map(attrs)
    booking_id = int_field(attrs["booking_id"], nil)

    cond do
      booking_id && booking_paid?(booking_id) ->
        {:error, :already_paid}

      booking_id && get_pending_payment_for_booking(booking_id) ->
        {:error, :payment_pending}

      true ->
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
    booking_id = booking.id

    cond do
      booking_paid?(booking_id) ->
        {:error, :already_paid}

      get_pending_payment_for_booking(booking_id) ->
        {:error, :payment_pending}

      base_amount_cents + fee_cents <= 0 ->
        {:error, :zero_amount}

      true ->
        do_start_stripe_checkout(booking, payer, base_amount_cents, fee_cents)
    end
  end

  defp do_start_stripe_checkout(booking, payer, base_amount_cents, fee_cents) do
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
    with :ok <- ensure_session_paid(session),
         {:ok, payment} <- find_payment_for_session(session) do
      complete_stripe_payment(payment, session)
    end
  end

  def ensure_session_paid(%{"payment_status" => "paid"}), do: :ok
  def ensure_session_paid(_), do: {:error, :not_paid}

  defp find_payment_for_session(session) do
    session_id = session["id"]

    payment =
      if is_binary(session_id) do
        get_payment_by_stripe_session(session_id) ||
          payment_from_metadata(session)
      else
        payment_from_metadata(session)
      end

    case payment do
      nil -> {:error, :not_found}
      %Payment{} = p -> {:ok, p}
    end
  end

  defp payment_from_metadata(session) do
    case get_in(session, ["metadata", "payment_id"]) do
      nil ->
        nil

      v when is_binary(v) ->
        case Integer.parse(v) do
          {id, _} -> Repo.get(Payment, id)
          :error -> nil
        end
    end
  end

  defp complete_stripe_payment(%Payment{} = payment, session) do
    if payment.status == "completed" do
      {:ok, payment}
    else
      if booking_paid?(payment.booking_id) do
        {:error, :already_paid}
      else
        ref =
          case session["payment_intent"] do
            pi when is_binary(pi) -> pi
            _ -> session["id"]
          end

        pi_str =
          case session["payment_intent"] do
            pi when is_binary(pi) -> pi
            _ -> nil
          end

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

  @doc "Verifies a Stripe checkout session belongs to the expected booking and payer context."
  def verify_checkout_session_for_booking(session, booking_id, payer_id) when is_map(session) do
    meta_booking =
      case get_in(session, ["metadata", "booking_id"]) do
        v when is_binary(v) -> String.to_integer(v)
        _ -> nil
      end

    payment =
      case find_payment_for_session(session) do
        {:ok, p} -> p
        _ -> nil
      end

    cond do
      meta_booking != nil and meta_booking != booking_id ->
        {:error, :booking_mismatch}

      payment != nil and payment.booking_id != booking_id ->
        {:error, :booking_mismatch}

      payment != nil and payment.payer_id != payer_id ->
        {:error, :payer_mismatch}

      true ->
        :ok
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
