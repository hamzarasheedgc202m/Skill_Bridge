# Script for populating the database. Run with: mix run priv/repo/seeds.exs
import Ecto.Query
alias SkillBridge.Repo
alias SkillBridge.Accounts.User
alias SkillBridge.Skills.SkillCategory
alias SkillBridge.Skills.SkilledProfile
alias SkillBridge.Skills.AvailabilitySlot
alias SkillBridge.Bookings.Booking

# ---------- Skill categories ----------
categories = [
  %{name: "Electrician", slug: "electrician"},
  %{name: "Plumber", slug: "plumber"},
  %{name: "Mechanic", slug: "mechanic"},
  %{name: "Civil Engineer", slug: "civil_engineer"},
  %{name: "Architect", slug: "architect"},
  %{name: "Software Engineer", slug: "software_engineer"},
  %{name: "Teacher", slug: "teacher"},
  %{name: "Other", slug: "other"}
]

for attrs <- categories do
  case Repo.get_by(SkillCategory, slug: attrs.slug) do
    nil -> %SkillCategory{} |> SkillCategory.changeset(attrs) |> Repo.insert!()
    _ -> :ok
  end
end

# ---------- Single admin (only one admin / company) ----------
admin =
  case Repo.get_by(User, email: "admin@skillbridge.local") do
    nil ->
      %User{}
      |> User.changeset(%{
        email: "admin@skillbridge.local",
        name: "Skill Bridge Admin",
        role: "admin",
        password: "admin123"
      })
      |> Repo.insert!()

    existing ->
      existing
  end

# ---------- Demo users (customers who hire) ----------
demo_users = [
  %{
    email: "alice@demo.local",
    name: "Alice Smith",
    password: "demo123",
    role: "user",
    age: 28,
    gender: "female",
    education_level: "bachelor",
    phone: "03001230001",
    province: "Punjab",
    district: "Lahore",
    tehsil: "Lahore City",
    city: "Lahore",
    profile_image_path: "/images/logo.svg"
  },
  %{
    email: "bob@demo.local",
    name: "Bob Jones",
    password: "demo123",
    role: "user",
    age: 35,
    gender: "male",
    education_level: "master",
    phone: "03001230002",
    province: "Punjab",
    district: "Lahore",
    tehsil: "Lahore City",
    city: "Lahore",
    profile_image_path: "/images/logo.svg"
  },
  %{
    email: "carol@demo.local",
    name: "Carol Lee",
    password: "demo123",
    role: "user",
    age: 42,
    gender: "female",
    education_level: "intermediate",
    phone: "03001230003",
    province: "Punjab",
    district: "Lahore",
    tehsil: "Lahore City",
    city: "Lahore",
    profile_image_path: "/images/logo.svg"
  }
]

_users_inserted =
  Enum.reduce(demo_users, %{}, fn attrs, acc ->
    case Repo.get_by(User, email: attrs.email) do
      nil ->
        u = %User{} |> User.changeset(attrs) |> Repo.insert!()
        Map.put(acc, attrs.email, u)

      _ ->
        acc
    end
  end)

# ---------- Demo skilled persons ----------
electrician_cat = Repo.get_by!(SkillCategory, slug: "electrician")
plumber_cat = Repo.get_by!(SkillCategory, slug: "plumber")
mechanic_cat = Repo.get_by!(SkillCategory, slug: "mechanic")
teacher_cat = Repo.get_by!(SkillCategory, slug: "teacher")

skilled_persons = [
  %{
    email: "john@demo.local",
    name: "John Davis",
    password: "demo123",
    role: "skilled_person",
    category: electrician_cat,
    region: "Downtown",
    bio: "Licensed electrician, 10+ years experience.",
    phone: "03001230101",
    age: 38,
    gender: "male",
    education_level: "bachelor"
  },
  %{
    email: "jane@demo.local",
    name: "Jane Wilson",
    password: "demo123",
    role: "skilled_person",
    category: plumber_cat,
    region: "North Side",
    bio: "Residential and commercial plumbing.",
    phone: "03001230102",
    age: 33,
    gender: "female",
    education_level: "bachelor"
  },
  %{
    email: "mike@demo.local",
    name: "Mike Brown",
    password: "demo123",
    role: "skilled_person",
    category: mechanic_cat,
    region: "West End",
    bio: "Auto mechanic, all brands.",
    phone: "03001230103",
    age: 41,
    gender: "male",
    education_level: "matric"
  },
  %{
    email: "sarah@demo.local",
    name: "Sarah Khan",
    password: "demo123",
    role: "skilled_person",
    category: teacher_cat,
    region: "Central",
    bio: "Math and science tutoring, K-12.",
    phone: "03001230104",
    age: 29,
    gender: "female",
    education_level: "master"
  }
]

profiles_inserted = %{}

{_skilled_users, profiles_inserted} =
  Enum.reduce(skilled_persons, {%{}, profiles_inserted}, fn attrs, {user_acc, profile_acc} ->
    user =
      case Repo.get_by(User, email: attrs.email) do
        nil ->
          u =
            %User{}
            |> User.changeset(
              Map.merge(
                %{
                  email: attrs.email,
                  name: attrs.name,
                  password: attrs.password,
                  role: attrs.role
                },
                Map.take(attrs, [
                  :age,
                  :gender,
                  :education_level,
                  :phone,
                  :province,
                  :district,
                  :tehsil,
                  :city,
                  :profile_image_path
                ])
              )
            )
            |> Repo.insert!()

          u

        existing ->
          existing
      end

    profile =
      case SkillBridge.Skills.get_skilled_profile_by_user_id(user.id) do
        nil ->
          {:ok, profile} =
            SkillBridge.Skills.create_skilled_profile_seed(%{
              user_id: user.id,
              skill_category_id: attrs.category.id,
              region: attrs.region,
              bio: attrs.bio,
              hourly_rate_cents: 2500,
              province: "Punjab",
              district: "Lahore",
              tehsil: "Lahore City",
              city: "Lahore",
              profile_image_url: "/images/logo.svg",
              age: attrs.age,
              gender: attrs.gender,
              education_level: attrs.education_level,
              phone: attrs.phone
            })

          _ =
            user
            |> User.changeset(%{
              age: attrs.age,
              gender: attrs.gender,
              education_level: attrs.education_level,
              phone: attrs.phone,
              province: "Punjab",
              district: "Lahore",
              tehsil: "Lahore City",
              city: "Lahore",
              profile_image_path: "/images/logo.svg"
            })
            |> Repo.update!()

          profile

        existing ->
          existing
      end

    {Map.put(user_acc, attrs.email, user), Map.put(profile_acc, attrs.email, profile)}
  end)

# ---------- Availability slots (Mon–Fri 9–17 for each profile) ----------
for {_email, profile} <- profiles_inserted do
  existing = SkillBridge.Skills.list_availability_slots(profile.id)

  if existing == [] do
    for day <- 1..5 do
      %AvailabilitySlot{}
      |> AvailabilitySlot.changeset(%{
        skilled_profile_id: profile.id,
        day_of_week: day,
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00]
      })
      |> Repo.insert!()
    end
  end
end

# ---------- Approve some skilled profiles (admin only can approve) ----------
approved_emails = ["john@demo.local", "jane@demo.local", "mike@demo.local"]
now = DateTime.utc_now() |> DateTime.truncate(:second)

for email <- approved_emails do
  profile = profiles_inserted[email]

  if profile && is_nil(profile.approved_at) do
    profile
    |> Ecto.Changeset.change(%{approved_at: now, approved_by_id: admin.id})
    |> Repo.update!()
  end
end

# Reload profiles after approval for booking creation
profiles_by_email =
  Enum.into(approved_emails, %{}, fn email ->
    user = Repo.get_by!(User, email: email)
    profile = SkillBridge.Skills.get_skilled_profile_by_user_id(user.id)
    {email, profile}
  end)

# ---------- Demo bookings ----------
alice = Repo.get_by!(User, email: "alice@demo.local")
bob = Repo.get_by!(User, email: "bob@demo.local")
john_p = profiles_by_email["john@demo.local"]
jane_p = profiles_by_email["jane@demo.local"]
mike_p = profiles_by_email["mike@demo.local"]

# Future datetimes: next Monday 10:00, 14:00, 11:30 UTC (within Mon–Fri 9–17 availability)
today = Date.utc_today()
days_until_monday = 8 - Date.day_of_week(today, :monday)
next_monday = Date.add(today, days_until_monday)
slot1 = DateTime.new!(next_monday, ~T[10:00:00], "Etc/UTC")
slot2 = DateTime.new!(next_monday, ~T[14:00:00], "Etc/UTC")
slot3 = DateTime.new!(next_monday, ~T[11:30:00], "Etc/UTC")

demo_bookings = [
  %{
    user_id: alice.id,
    skilled_profile_id: john_p.id,
    scheduled_at: slot1,
    status: "pending",
    address: "123 Main St, Downtown"
  },
  %{
    user_id: bob.id,
    skilled_profile_id: jane_p.id,
    scheduled_at: slot2,
    status: "confirmed",
    address: "456 Oak Ave, North Side"
  },
  %{
    user_id: alice.id,
    skilled_profile_id: mike_p.id,
    scheduled_at: slot3,
    status: "confirmed",
    address: "789 Elm Rd, West End"
  }
]

for attrs <- demo_bookings do
  case Repo.all(
         from b in Booking,
           where:
             b.user_id == ^attrs.user_id and b.skilled_profile_id == ^attrs.skilled_profile_id and
               b.scheduled_at == ^attrs.scheduled_at
       ) do
    [] ->
      %Booking{}
      |> Booking.changeset(attrs)
      |> Repo.insert!()

    _ ->
      :ok
  end
end

IO.puts("""
Seeds completed.

  Admin (single account, restricted area):
    admin@skillbridge.local / admin123

  Demo users (password: demo123):
    alice@demo.local  – Alice Smith
    bob@demo.local    – Bob Jones
    carol@demo.local  – Carol Lee

  Demo skilled persons (password: demo123):
    john@demo.local   – John Davis (Electrician, Downtown) [approved]
    jane@demo.local   – Jane Wilson (Plumber, North Side) [approved]
    mike@demo.local   – Mike Brown (Mechanic, West End) [approved]
    sarah@demo.local  – Sarah Khan (Teacher, Central) [pending approval]

  Demo bookings created for Alice and Bob.
""")

# ---------- Admin secret key (platform owner key) ----------
# This is the special key required at /admin/login in addition to email+password.
# Change this to something secret before going to production!
IO.puts("Setting admin secret key...")
SkillBridge.Moderation.set_admin_key("SKILLBRIDGE-ADMIN-2026")

IO.puts("""

  Admin portal: http://localhost:4000/admin/login
    Email    : admin@skillbridge.local
    Password : admin123
    Admin Key: SKILLBRIDGE-ADMIN-2026

  *** Change the Admin Key before deploying to production! ***
""")

# ---------- Platform fee settings ----------
alias SkillBridge.Payments.PlatformSetting

case SkillBridge.Repo.one(from s in PlatformSetting, limit: 1) do
  nil ->
    %PlatformSetting{}
    |> PlatformSetting.changeset(%{platform_fee_type: "percentage", platform_fee_value: 10})
    |> SkillBridge.Repo.insert!()

  _ ->
    :ok
end

IO.puts("Platform fee: 10% (configurable in Admin > Settings)")
