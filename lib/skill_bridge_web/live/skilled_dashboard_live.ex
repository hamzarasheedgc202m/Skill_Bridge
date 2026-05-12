defmodule SkillBridgeWeb.SkilledDashboardLive do
  use SkillBridgeWeb, :live_view
  embed_templates "skilled_dashboard_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Bookings
  alias SkillBridge.Payments

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    profile = Skills.get_skilled_profile_by_user_id(user.id)
    completion = Skills.profile_completion(profile)
    bookings = if profile, do: Bookings.list_bookings_for_skilled_profile(profile.id), else: []
    earnings = if profile, do: Payments.skilled_person_earnings(profile.id), else: 0
    slots = if profile, do: Skills.list_availability_slots(profile.id), else: []

    if connected?(socket), do: :timer.send_interval(1000, :tick)

    now = pkt_now()

    {:ok,
     socket
     |> assign(:page_title, "Skilled dashboard")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:profile, profile)
     |> assign(:completion, completion)
     |> assign(:onboarding_steps, onboarding_steps(completion))
     |> assign(:bookings, bookings)
     |> assign(:earnings_cents, earnings)
     |> assign(:slots, slots)
     |> assign_time_data(now)}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign_time_data(socket, pkt_now())}
  end

  # UTC + 5 = PKT
  defp pkt_now, do: DateTime.add(DateTime.utc_now(), 5 * 3600, :second)

  defp assign_time_data(socket, now) do
    slots = socket.assigns[:slots] || []
    bookings = socket.assigns[:bookings] || []

    # day_of_week: 0=Sun, 1=Mon ... 6=Sat (matching AvailabilitySlot convention)
    current_day = rem(Date.day_of_week(DateTime.to_date(now)), 7)
    current_time = Time.new!(now.hour, now.minute, now.second)

    active_slot =
      Enum.find(slots, fn slot ->
        slot_day = Map.get(slot, :day_of_week)
        start_t = Map.get(slot, :start_time)
        end_t = Map.get(slot, :end_time)

        is_integer(slot_day) and slot_day == current_day and
          start_t != nil and end_t != nil and
          Time.compare(current_time, start_t) != :lt and
          Time.compare(current_time, end_t) != :gt
      end)

    countdown_secs =
      case active_slot do
        nil ->
          nil

        slot ->
          end_t = slot.end_time || Map.get(slot, :end_time)

          if end_t do
            end_s = end_t.hour * 3600 + end_t.minute * 60 + end_t.second
            now_s = now.hour * 3600 + now.minute * 60 + now.second
            max(0, end_s - now_s)
          end
      end

    today_date = DateTime.to_date(now)

    today_bookings =
      Enum.filter(bookings, fn b ->
        b.scheduled_at != nil and
          DateTime.to_date(b.scheduled_at) == today_date and
          b.status in ["pending", "confirmed"]
      end)

    socket
    |> assign(:now, now)
    |> assign(:active_slot, active_slot)
    |> assign(:countdown_secs, countdown_secs)
    |> assign(:today_bookings, today_bookings)
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp onboarding_steps(completion) do
    items = Map.merge(empty_completion_items(), completion.items)

    [
      %{
        label: "Upload profile photo",
        done: item_done?(items, :photo),
        path: ~p"/skilled/profile"
      },
      %{
        label: "Complete personal details (age, phone, …)",
        done: item_done?(items, :personal),
        path: ~p"/skilled/profile"
      },
      %{
        label: "Set your exact map pin",
        done: item_done?(items, :location_pin),
        path: ~p"/skilled/profile"
      },
      %{
        label: "Add skill, rate, and bio",
        done:
          item_done?(items, :skill_category) and item_done?(items, :rate) and
            item_done?(items, :bio),
        path: ~p"/skilled/profile"
      },
      %{
        label: "Set weekly availability",
        done: item_done?(items, :availability),
        path: ~p"/skilled/availability"
      }
    ]
  end

  defp empty_completion_items do
    %{
      photo: false,
      personal: false,
      skill_category: false,
      bio: false,
      rate: false,
      city: false,
      location_pin: false,
      availability: false
    }
  end

  defp item_done?(items, key), do: Map.get(items, key) == true

  @impl true
  def render(assigns), do: index(assigns)
end
