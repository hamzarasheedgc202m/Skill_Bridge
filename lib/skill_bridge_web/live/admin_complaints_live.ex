defmodule SkillBridgeWeb.AdminComplaintsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_complaints_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Moderation

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)

    {:ok,
     socket
     |> assign(:page_title, "Complaints — SkillBridge Admin")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:filter_status, "open")
     |> reload_complaints()}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp reload_complaints(socket) do
    complaints = Moderation.list_all_complaints()
    assign(socket, :complaints, complaints)
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  def handle_event("resolve", %{"id" => id}, socket) do
    complaint = Moderation.get_complaint!(id)

    case Moderation.resolve_complaint(complaint) do
      {:ok, _} ->
        {:noreply,
         socket |> reload_complaints() |> put_flash(:info, "Complaint ##{id} marked resolved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not resolve complaint.")}
    end
  end

  def handle_event("reopen", %{"id" => id}, socket) do
    complaint = Moderation.get_complaint!(id)

    case Moderation.reopen_complaint(complaint) do
      {:ok, _} ->
        {:noreply,
         socket |> reload_complaints() |> put_flash(:info, "Complaint ##{id} reopened.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reopen complaint.")}
    end
  end

  defp visible_complaints(complaints, "all"), do: complaints

  defp visible_complaints(complaints, status) do
    Enum.filter(complaints, &(&1.status == status))
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :visible, visible_complaints(assigns.complaints, assigns.filter_status))

    index(assigns)
  end
end
