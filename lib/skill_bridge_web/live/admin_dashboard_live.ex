defmodule SkillBridgeWeb.AdminDashboardLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_dashboard_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Moderation
  alias SkillBridge.Payments

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    pending = Skills.list_pending_skilled_profiles()
    approved = Skills.list_skilled_profiles(approved_only: true)
    frozen = Moderation.list_frozen_users()
    all_complaints = Moderation.list_all_complaints()
    total_bookings = SkillBridge.Repo.aggregate(SkillBridge.Bookings.Booking, :count, :id)
    open_complaints = Enum.count(all_complaints, &(&1.status == "open"))
    revenue = Payments.platform_revenue()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard — SkillBridge")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:pending_count, length(pending))
     |> assign(:approved_count, length(approved))
     |> assign(:frozen_count, length(frozen))
     |> assign(:open_complaints, open_complaints)
     |> assign(:total_bookings, total_bookings)
     |> assign(:revenue, revenue)}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
