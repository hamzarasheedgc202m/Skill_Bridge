defmodule SkillBridge.LocationTest do
  use SkillBridge.DataCase, async: true

  alias SkillBridge.{Accounts, Location, Repo, Skills}

  setup do
    category =
      %Skills.SkillCategory{}
      |> Skills.SkillCategory.changeset(%{name: "Loc", slug: "loc_#{System.unique_integer()}"})
      |> Repo.insert!()

    user =
      %Accounts.User{}
      |> Accounts.User.changeset(%{
        email: "loc-#{System.unique_integer()}@test.local",
        name: "Worker",
        role: "skilled_person",
        password: "password123"
      })
      |> Repo.insert!()

    {:ok, profile} =
      Skills.create_skilled_profile_seed(%{
        user_id: user.id,
        skill_category_id: category.id,
        status: "approved",
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second),
        bio: "Test",
        region: "Lahore"
      })

    %{profile: profile}
  end

  test "toggle_sharing on without GPS row returns awaiting_position", %{profile: profile} do
    assert {:ok, :awaiting_position} = Location.toggle_sharing(profile.id, true)
    assert Location.get_worker_location(profile.id) == nil
  end

  test "upsert_location stores fuzzed coordinates", %{profile: profile} do
    assert {:ok, loc} = Location.upsert_location(profile.id, 31.5204, 74.3587, true)
    assert loc.is_sharing
    assert loc.latitude != 31.5204 or loc.longitude != 74.3587
  end
end
