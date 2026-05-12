defmodule SkillBridgeWeb.SkilledAvailabilityLive do
  use SkillBridgeWeb, :live_view
  embed_templates "skilled_availability_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Skills.AvailabilitySlot

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    profile = Skills.get_skilled_profile_by_user_id(user.id)
    slots = if profile, do: Skills.list_availability_slots(profile.id), else: []

    {:ok,
     socket
     |> assign(:page_title, "Availability")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:profile, profile)
     |> assign(:slots, slots)
     |> assign(:day_options, day_options())
     |> assign(:saving, false)}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp day_options do
    Enum.map(0..6, fn d -> {AvailabilitySlot.day_name(d), d} end)
  end

  @impl true
  def handle_event("add_slot", _, socket) do
    slots = socket.assigns.slots ++ [%{day_of_week: 1, start_time: "09:00", end_time: "17:00"}]
    {:noreply, assign(socket, :slots, slots)}
  end

  @impl true
  def handle_event("remove_slot", %{"index" => idx}, socket) do
    slots = List.delete_at(socket.assigns.slots, String.to_integer(idx))
    {:noreply, assign(socket, :slots, slots)}
  end

  @impl true
  def handle_event("save", params, socket) do
    profile = socket.assigns.profile

    unless profile do
      {:noreply,
       socket
       |> put_flash(:error, "Create your profile first.")
       |> push_navigate(to: ~p"/skilled/profile")}
    else
      # Phoenix sends indexed params: %{"0" => %{"day_of_week" => "1", ...}, "1" => ...}
      slots_raw = Map.get(params, "slots", %{})

      slots_list =
        cond do
          is_map(slots_raw) and map_size(slots_raw) == 0 ->
            []

          is_map(slots_raw) ->
            slots_raw
            |> Map.keys()
            |> Enum.sort_by(&String.to_integer/1)
            |> Enum.map(&Map.get(slots_raw, &1))

          is_list(slots_raw) ->
            slots_raw

          true ->
            []
        end

      slots_attrs =
        Enum.map(slots_list, fn s ->
          %{
            "day_of_week" => parse_int(s["day_of_week"]),
            "start_time" => to_time(s["start_time"]),
            "end_time" => to_time(s["end_time"])
          }
        end)

      case Skills.set_availability_slots(profile.id, slots_attrs) do
        {:ok, saved_slots} ->
          # Reload fresh slots from DB to confirm persistence
          fresh_slots = Skills.list_availability_slots(profile.id)

          {:noreply,
           socket
           |> assign(:slots, fresh_slots)
           |> assign(:saving, false)
           |> put_flash(:info, "#{length(saved_slots)} slot(s) saved successfully!")}

        {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
          msg =
            changeset.errors
            |> Enum.map(fn {f, {m, _}} -> "#{f}: #{m}" end)
            |> Enum.join(", ")

          {:noreply,
           socket
           |> assign(:saving, false)
           |> put_flash(:error, "Could not save: #{msg}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:saving, false)
           |> put_flash(:error, "Something went wrong: #{inspect(reason)}")}
      end
    end
  end

  defp parse_int(nil), do: 1
  defp parse_int(""), do: 1
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(n), do: n

  defp to_time(nil), do: ~T[09:00:00]
  defp to_time(""), do: ~T[09:00:00]
  defp to_time(%Time{} = t), do: t

  defp to_time(s) when is_binary(s) do
    case String.split(s, ":", parts: 3) do
      [h, m] ->
        Time.from_iso8601!("#{String.pad_leading(h, 2, "0")}:#{String.pad_leading(m, 2, "0")}:00")

      [h, m, sec] ->
        Time.from_iso8601!(
          "#{String.pad_leading(h, 2, "0")}:#{String.pad_leading(m, 2, "0")}:#{String.pad_leading(sec, 2, "0")}"
        )

      _ ->
        ~T[09:00:00]
    end
  rescue
    _ -> ~T[09:00:00]
  end

  defp to_time(_), do: ~T[09:00:00]

  defp get_slot_value(slot, key) when is_atom(key) do
    cond do
      is_map(slot) and Map.has_key?(slot, :__struct__) -> Map.get(slot, key)
      is_map(slot) and Map.has_key?(slot, key) -> Map.get(slot, key)
      is_map(slot) and Map.has_key?(slot, to_string(key)) -> Map.get(slot, to_string(key))
      true -> nil
    end
  end

  defp time_to_string(%Time{} = t),
    do:
      "#{String.pad_leading(Integer.to_string(t.hour), 2, "0")}:#{String.pad_leading(Integer.to_string(t.minute), 2, "0")}"

  defp time_to_string(s) when is_binary(s), do: s
  defp time_to_string(_), do: "09:00"

  defp day_gradient(0), do: "from-rose-500/20 to-rose-400/5 border-rose-400/40"
  defp day_gradient(1), do: "from-violet-500/20 to-violet-400/5 border-violet-400/40"
  defp day_gradient(2), do: "from-sky-500/20 to-sky-400/5 border-sky-400/40"
  defp day_gradient(3), do: "from-emerald-500/20 to-emerald-400/5 border-emerald-400/40"
  defp day_gradient(4), do: "from-amber-500/20 to-amber-400/5 border-amber-400/40"
  defp day_gradient(5), do: "from-pink-500/20 to-pink-400/5 border-pink-400/40"
  defp day_gradient(6), do: "from-teal-500/20 to-teal-400/5 border-teal-400/40"
  defp day_gradient(_), do: "from-slate-500/20 to-slate-400/5 border-slate-400/40"

  @impl true
  def render(assigns), do: index(assigns)
end
