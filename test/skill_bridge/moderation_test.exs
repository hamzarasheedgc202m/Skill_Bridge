defmodule SkillBridge.ModerationTest do
  use SkillBridge.DataCase, async: true

  alias SkillBridge.{Accounts, Moderation, Repo, Skills}
  alias SkillBridge.Bookings.Booking

  setup do
    category =
      %Skills.SkillCategory{}
      |> Skills.SkillCategory.changeset(%{name: "Test", slug: "test_mod"})
      |> Repo.insert!()

    client =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "mod-client-#{System.unique_integer()}@test.local",
        name: "Client",
        role: "user",
        password: "password123"
      })
      |> Repo.insert!()

    pro_user =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "mod-pro-#{System.unique_integer()}@test.local",
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
        bio: "Bio",
        region: "Lahore"
      })

    booking =
      %Booking{}
      |> Booking.changeset(%{
        user_id: client.id,
        skilled_profile_id: profile.id,
        scheduled_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
        status: "confirmed",
        address: "123 Test Street"
      })
      |> Repo.insert!()

    %{client: client, profile: profile, booking: booking}
  end

  test "create_review_for_booking requires completed status", %{
    client: client,
    profile: profile,
    booking: booking
  } do
    assert {:error, :booking_not_completed} =
             Moderation.create_review_for_booking(booking, client, %{
               "rating" => 5,
               "body" => "Great",
               "user_id" => client.id,
               "skilled_profile_id" => profile.id
             })
  end

  test "create_complaint_for_booking allows confirmed booking", %{
    client: client,
    profile: profile,
    booking: booking
  } do
    assert {:ok, _} =
             Moderation.create_complaint_for_booking(booking, client, %{
               "body" => "Issue during service visit",
               "user_id" => client.id,
               "skilled_profile_id" => profile.id
             })
  end
end
