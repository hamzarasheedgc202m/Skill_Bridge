defmodule SkillBridge.PaymentsTest do
  use SkillBridge.DataCase, async: true

  alias SkillBridge.{Accounts, Payments, Repo, Skills}
  alias SkillBridge.Bookings.Booking
  alias SkillBridge.Payments.Payment
  alias SkillBridge.Payments.CardCheckout

  setup do
    category =
      %Skills.SkillCategory{}
      |> Skills.SkillCategory.changeset(%{
        name: "Pay Cat",
        slug: "pay_cat_#{System.unique_integer()}"
      })
      |> Repo.insert!()

    client =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "client-pay-#{System.unique_integer()}@test.local",
        name: "Client",
        role: "user",
        password: "password123"
      })
      |> Repo.insert!()

    pro_user =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "pro-pay-#{System.unique_integer()}@test.local",
        name: "Pro",
        role: "skilled_person",
        password: "password123"
      })
      |> Repo.insert!()

    {:ok, profile} =
      Skills.create_skilled_profile_seed(%{
        user_id: pro_user.id,
        skill_category_id: category.id,
        status: "approved",
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second),
        bio: "Test",
        region: "Lahore",
        hourly_rate_cents: 500_000
      })

    booking =
      %Booking{}
      |> Booking.changeset(%{
        user_id: client.id,
        skilled_profile_id: profile.id,
        scheduled_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
        address: "Test St",
        status: "confirmed"
      })
      |> Repo.insert!()

    %{client: client, booking: booking}
  end

  test "card checkout validates stripe test card" do
    assert {:ok, %{card_last4: "4242"}} =
             CardCheckout.validate(%{
               "card_number" => "4242 4242 4242 4242",
               "expiry" => "12/30",
               "cvc" => "123",
               "cardholder_name" => "Test User"
             })
  end

  test "card checkout rejects declined test card" do
    assert {:error, _} =
             CardCheckout.validate(%{
               "card_number" => "4000 0000 0000 0002",
               "expiry" => "12/30",
               "cvc" => "123",
               "cardholder_name" => "Test User"
             })
  end

  test "create_simulated_payment marks booking paid", %{client: client, booking: booking} do
    assert {:ok, %Payment{status: "completed"}} =
             Payments.create_simulated_payment(%{
               "amount_cents" => 5000,
               "booking_id" => booking.id,
               "payer_id" => client.id,
               "payment_method" => "card",
               "card_last4" => "4242"
             })

    assert Payments.booking_paid?(booking.id)
  end

  test "cannot pay twice for same booking", %{client: client, booking: booking} do
    attrs = %{
      "amount_cents" => 5000,
      "booking_id" => booking.id,
      "payer_id" => client.id,
      "payment_method" => "card"
    }

    assert {:ok, _} = Payments.create_simulated_payment(attrs)
    assert {:error, :already_paid} = Payments.create_simulated_payment(attrs)
  end

  test "manual payment pending blocks duplicate", %{client: client, booking: booking} do
    assert {:ok, _} =
             Payments.create_pending_manual_payment(%{
               "amount_cents" => 5000,
               "booking_id" => booking.id,
               "payer_id" => client.id,
               "payment_method" => "bank"
             })

    assert {:error, :payment_pending} =
             Payments.create_pending_manual_payment(%{
               "amount_cents" => 5000,
               "booking_id" => booking.id,
               "payer_id" => client.id,
               "payment_method" => "bank"
             })
  end

  test "sync_payment_from_checkout_session completes stripe payment", %{
    client: client,
    booking: booking
  } do
    {:ok, payment} =
      Payments.create_pending_stripe_payment(%{
        "amount_cents" => 5500,
        "platform_fee_cents" => 500,
        "booking_id" => booking.id,
        "payer_id" => client.id
      })

    session = %{
      "id" => "cs_test_123",
      "payment_status" => "paid",
      "payment_intent" => "pi_test_123",
      "metadata" => %{
        "payment_id" => to_string(payment.id),
        "booking_id" => to_string(booking.id)
      }
    }

    assert {:ok, %Payment{status: "completed"}} =
             Payments.sync_payment_from_checkout_session(session)

    assert Payments.booking_paid?(booking.id)
  end
end
