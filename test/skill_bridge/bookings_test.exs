defmodule SkillBridge.BookingsTest do
  use SkillBridge.DataCase, async: true

  alias SkillBridge.{Accounts, Bookings, Repo, Skills}
  alias SkillBridge.Bookings.Booking
  alias SkillBridge.Skills.AvailabilitySlot

  setup do
    category =
      %Skills.SkillCategory{}
      |> Skills.SkillCategory.changeset(%{name: "Test", slug: "test_cat"})
      |> Repo.insert!()

    client =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "client-#{System.unique_integer()}@test.local",
        name: "Client",
        role: "user",
        password: "password123"
      })
      |> Repo.insert!()

    pro_user =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "pro-#{System.unique_integer()}@test.local",
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
        bio: "Test bio",
        region: "Lahore"
      })

    slot = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

    %AvailabilitySlot{}
    |> Skills.AvailabilitySlot.changeset(%{
      skilled_profile_id: profile.id,
      day_of_week: Date.day_of_week(DateTime.to_date(slot), :sunday) - 1,
      start_time: ~T[00:00:00],
      end_time: ~T[23:59:59]
    })
    |> Repo.insert!()

    %{client: client, profile: profile, slot: slot}
  end

  test "slot_taken? detects existing booking", %{client: client, profile: profile, slot: slot} do
    refute Bookings.slot_taken?(profile.id, slot)

    %Booking{}
    |> Booking.changeset(%{
      user_id: client.id,
      skilled_profile_id: profile.id,
      scheduled_at: slot,
      status: "pending",
      address: "123 Test Street, Lahore"
    })
    |> Repo.insert!()

    assert Bookings.slot_taken?(profile.id, slot)
  end

  test "create_booking rejects taken slot", %{client: client, profile: profile, slot: slot} do
    attrs = %{
      "user_id" => client.id,
      "skilled_profile_id" => profile.id,
      "scheduled_at" => slot,
      "status" => "pending",
      "address" => "123 Test Street, Lahore"
    }

    assert {:ok, _} = Bookings.create_booking(attrs)
    assert {:error, :slot_taken} = Bookings.create_booking(attrs)
  end
end
