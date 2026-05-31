defmodule SkillBridgeWeb.BookLive do
  use SkillBridgeWeb, :live_view
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Bookings
  alias SkillBridge.Skills.AvailabilitySlot
  embed_templates "book_live_html/*"

  @impl true
  def mount(%{"profile_id" => profile_id} = params, session, socket) do
    user = fetch_user(session)

    profile =
      Skills.get_skilled_profile!(profile_id,
        preload: [:user, :skill_category, :availability_slots]
      )

    unless Skills.SkilledProfile.approved?(profile) do
      {:ok,
       socket
       |> put_flash(:error, "This professional is not yet approved.")
       |> push_navigate(to: ~p"/user/browse")}
    else
      selected_slot =
        case socket.assigns.live_action do
          :confirm -> parse_selected_slot(params)
          _ -> nil
        end

      {:ok,
       socket
       |> assign(:page_title, "Book — #{profile.user.name}")
       |> assign(:current_user, user)
       |> assign(:current_scope, user.role)
       |> assign(:profile, profile)
       |> assign(:selected_slot, selected_slot)
       |> assign(:submitting, false)
       |> assign(:addr, "")
       |> assign(:notes, "")
       |> assign(:scheduled_at, (selected_slot && selected_slot.prefilled_datetime) || "")
       |> assign(:errors, %{})}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp slots_by_day(slots) do
    slots
    |> Enum.group_by(& &1.day_of_week)
    |> Enum.sort_by(fn {day, _} -> day end)
  end

  defp fmt_time(%{hour: h, minute: m}) do
    ampm = if h < 12, do: "AM", else: "PM"

    h12 =
      cond do
        h == 0 -> 12
        h > 12 -> h - 12
        true -> h
      end

    "#{String.pad_leading(to_string(h12), 2, "0")}:#{String.pad_leading(to_string(m), 2, "0")} #{ampm}"
  end

  defp fmt_time(_), do: ""

  defp day_short(0), do: "SUN"
  defp day_short(1), do: "MON"
  defp day_short(2), do: "TUE"
  defp day_short(3), do: "WED"
  defp day_short(4), do: "THU"
  defp day_short(5), do: "FRI"
  defp day_short(6), do: "SAT"
  defp day_short(_), do: "?"

  defp day_full(n), do: AvailabilitySlot.day_name(n)

  defp parse_selected_slot(%{"slot_day" => day, "slot_start" => start_t, "slot_end" => end_t}) do
    with {day_int, ""} <- Integer.parse(day),
         {:ok, start_time} <- Time.from_iso8601(start_t <> ":00"),
         {:ok, end_time} <- Time.from_iso8601(end_t <> ":00") do
      %{
        day: day_int,
        start_time: start_time,
        end_time: end_time,
        start_label: fmt_time(start_time),
        end_label: fmt_time(end_time),
        prefilled_datetime: next_slot_datetime_local(day_int, start_time)
      }
    else
      _ -> nil
    end
  end

  defp parse_selected_slot(_), do: nil

  defp next_slot_datetime_local(day_of_week, start_time) do
    today = Date.utc_today()
    now = DateTime.utc_now()
    current_dow = Date.day_of_week(today, :sunday) - 1
    raw_offset = day_of_week - current_dow
    day_offset = if raw_offset < 0, do: raw_offset + 7, else: raw_offset
    slot_date = Date.add(today, day_offset)

    naive_slot =
      NaiveDateTime.new!(slot_date, Time.truncate(start_time, :second))

    chosen =
      if DateTime.compare(DateTime.from_naive!(naive_slot, "Etc/UTC"), now) == :lt do
        NaiveDateTime.add(naive_slot, 7 * 24 * 60 * 60, :second)
      else
        naive_slot
      end

    Calendar.strftime(chosen, "%Y-%m-%dT%H:%M")
  end

  # ── FIX: update individual fields so data is NEVER wiped ──────────────────
  @impl true
  def handle_event("set_addr", %{"value" => v}, socket), do: {:noreply, assign(socket, :addr, v)}

  def handle_event("set_notes", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :notes, v)}

  def handle_event("set_datetime", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :scheduled_at, v)}

  def handle_event("save", _params, socket) do
    addr = String.trim(socket.assigns.addr)
    dt = String.trim(socket.assigns.scheduled_at)
    notes = String.trim(socket.assigns.notes)

    errors = %{}
    errors = if addr == "", do: Map.put(errors, :addr, "Address is required"), else: errors
    errors = if dt == "", do: Map.put(errors, :dt, "Please choose a date & time"), else: errors

    if errors != %{} do
      {:noreply, assign(socket, :errors, errors)}
    else
      scheduled_at =
        case NaiveDateTime.from_iso8601(dt <> ":00") do
          {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
          _ -> nil
        end

      attrs = %{
        "user_id" => socket.assigns.current_user.id,
        "skilled_profile_id" => socket.assigns.profile.id,
        "status" => "pending",
        "address" => addr,
        "notes" => notes,
        "scheduled_at" => scheduled_at
      }

      {:noreply, assign(socket, :submitting, true)}

      case Bookings.create_booking(attrs) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:submitting, false)
           |> put_flash(:info, "✅ Booking requested! The professional will confirm shortly.")
           |> push_navigate(to: ~p"/user/bookings")}

        {:error, %Ecto.Changeset{} = cs} ->
          field_errors =
            Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)

          {:noreply, socket |> assign(:submitting, false) |> assign(:errors, field_errors)}

        {:error, :past_datetime} ->
          {:noreply,
           socket
           |> assign(:submitting, false)
           |> assign(:errors, %{dt: "Please choose a future date and time."})}

        {:error, :not_available} ->
          {:noreply,
           socket
           |> assign(:submitting, false)
           |> assign(:errors, %{
             dt:
               "This professional is not available at that time. Choose a time within the displayed slots."
           })}

        {:error, :slot_taken} ->
          {:noreply,
           socket
           |> assign(:submitting, false)
           |> assign(:errors, %{
             dt: "That time slot was just booked. Please choose another time."
           })}
      end
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
