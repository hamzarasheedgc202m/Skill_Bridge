defmodule SkillBridgeWeb.AdminSkilledPersonsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_skilled_persons_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Moderation
  alias SkillBridge.Repo

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)

    {:ok,
     socket
     |> assign(:page_title, "Manage Skilled Persons")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:active_tab, "pending")
     |> assign(:selected_profile, nil)
     |> assign(:complaints, [])
     |> assign(:reviews, [])
     |> reload_lists()}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp reload_lists(socket) do
    socket
    |> assign(:pending, Skills.list_pending_skilled_profiles())
    |> assign(:approved, Skills.list_skilled_profiles(approved_only: true))
    |> assign(:all, Skills.list_all_skilled_profiles())
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, selected_profile: nil)}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    profile = Skills.get_skilled_profile!(id)

    case Skills.approve_skilled_profile(profile, socket.assigns.current_user.id) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "✅ Profile approved.") |> reload_lists()}

      {:error, :location_required} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Cannot approve yet: provider must set an exact map pin location first."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not approve.")}
    end
  end

  def handle_event("reject", %{"id" => id}, socket) do
    profile = Skills.get_skilled_profile!(id)

    case Skills.reject_skilled_profile(profile) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Profile rejected.") |> reload_lists()}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not reject.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    profile = Skills.get_skilled_profile!(id)

    case Repo.delete(profile) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:selected_profile, nil)
         |> put_flash(:info, "Professional removed.")
         |> reload_lists()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove.")}
    end
  end

  def handle_event("freeze_profile", %{"id" => id}, socket) do
    profile = Skills.get_skilled_profile!(id)

    case Skills.freeze_profile(profile) do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, "Account frozen.") |> reload_lists() |> refresh_selected(id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not freeze.")}
    end
  end

  def handle_event("unfreeze_profile", %{"id" => id}, socket) do
    profile = Skills.get_skilled_profile!(id)

    case Skills.unfreeze_profile(profile) do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, "Account unfrozen.") |> reload_lists() |> refresh_selected(id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not unfreeze.")}
    end
  end

  def handle_event("view_detail", %{"id" => id}, socket) do
    profile = Skills.get_skilled_profile!(id)
    complaints = Moderation.list_complaints_for_profile(profile.id)
    reviews = Moderation.list_reviews_for_profile(profile.id)

    {:noreply,
     socket
     |> assign(:selected_profile, profile)
     |> assign(:complaints, complaints)
     |> assign(:reviews, reviews)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, :selected_profile, nil)}
  end

  def handle_event("resolve_complaint", %{"id" => cid}, socket) do
    complaint = Moderation.get_complaint!(cid)

    case Moderation.resolve_complaint(complaint) do
      {:ok, _} ->
        complaints = Moderation.list_complaints_for_profile(socket.assigns.selected_profile.id)

        {:noreply,
         socket |> put_flash(:info, "Complaint resolved.") |> assign(:complaints, complaints)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update.")}
    end
  end

  defp refresh_selected(socket, id) do
    case socket.assigns.selected_profile do
      %{id: ^id} ->
        profile = Skills.get_skilled_profile!(to_string(id))
        assign(socket, :selected_profile, profile)

      _ ->
        socket
    end
  end

  defp fmt_dt(nil), do: "—"
  defp fmt_dt(dt), do: Calendar.strftime(dt, "%d %b %Y")

  defp status_badge("pending"), do: {"⏳ Pending", "#D97706", "#FFFBEB"}
  defp status_badge("approved"), do: {"✅ Approved", "#065F46", "#F0FDF4"}
  defp status_badge("rejected"), do: {"❌ Rejected", "#991B1B", "#FEF2F2"}
  defp status_badge("frozen"), do: {"🚫 Frozen", "#1E40AF", "#EFF6FF"}
  defp status_badge(_), do: {"⏳ Pending", "#D97706", "#FFFBEB"}

  defp star(n), do: String.duplicate("⭐", n)

  @impl true
  def render(assigns), do: index(assigns)
end
