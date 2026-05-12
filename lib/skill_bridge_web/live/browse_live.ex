defmodule SkillBridgeWeb.BrowseLive do
  use SkillBridgeWeb, :live_view
  alias SkillBridge.Accounts
  alias SkillBridge.Skills
  embed_templates "browse_live_html/*"

  @category_icons %{
    "electrician" => "hero-bolt",
    "plumber" => "hero-wrench-screwdriver",
    "mechanic" => "hero-cog-6-tooth",
    "civil_engineer" => "hero-building-office-2",
    "architect" => "hero-home-modern",
    "software_engineer" => "hero-computer-desktop",
    "teacher" => "hero-academic-cap",
    "other" => "hero-briefcase"
  }

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    categories = Skills.list_skill_categories()

    {:ok,
     socket
     |> assign(:page_title, "Browse Services")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:categories, categories)
     |> assign(:search, "")
     |> assign(:search_results, nil)}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp get_icon(slug), do: Map.get(@category_icons, slug, "hero-briefcase")

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    q = String.trim(q)

    if q != "" do
      profiles = Skills.list_skilled_profiles(approved_only: true, search: q)
      {:noreply, socket |> assign(:search, q) |> assign(:search_results, profiles)}
    else
      {:noreply, socket |> assign(:search, "") |> assign(:search_results, nil)}
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
