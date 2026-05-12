defmodule SkillBridgeWeb.BrowseCategoryLive do
  use SkillBridgeWeb, :live_view

  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  alias SkillBridge.Skills.AvailabilitySlot
  embed_templates "browse_category_live_html/*"

  @impl true
  def mount(%{"category_id" => category_id}, session, socket) do
    user = fetch_user(session)
    category = Skills.get_skill_category!(category_id)
    profiles = Skills.list_skilled_profiles(skill_category_id: category.id, approved_only: true)

    {:ok,
     socket
     |> assign(:page_title, "#{category.name} Professionals")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:category, category)
     |> assign(:profiles, profiles)
     |> assign(:region, "")}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("filter_region", %{"region" => region}, socket) do
    profiles =
      Skills.list_skilled_profiles(
        skill_category_id: socket.assigns.category.id,
        approved_only: true,
        region: region
      )

    {:noreply, socket |> assign(:region, region) |> assign(:profiles, profiles)}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    profiles =
      Skills.list_skilled_profiles(
        skill_category_id: socket.assigns.category.id,
        approved_only: true
      )

    {:noreply, socket |> assign(:region, "") |> assign(:profiles, profiles)}
  end

  @impl true
  def render(assigns), do: index(assigns)
end
