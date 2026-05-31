defmodule SkillBridgeWeb.PublicBrowseLive do
  use SkillBridgeWeb, :live_view
  embed_templates "public_browse_live_html/*"
  alias SkillBridge.Moderation
  alias SkillBridge.Skills

  @icons %{
    "electrician" => "⚡",
    "plumber" => "🔧",
    "mechanic" => "🔩",
    "civil_engineer" => "🏗️",
    "architect" => "🏛️",
    "software_engineer" => "💻",
    "teacher" => "📚",
    "other" => "🛠️"
  }

  @impl true
  def mount(_params, session, socket) do
    current_user =
      case session["user_id"] do
        nil -> nil
        id -> SkillBridge.Accounts.get_user(id)
      end

    categories = Skills.list_skill_categories()

    {:ok,
     socket
     |> assign(:page_title, "Browse Services — SkillBridge")
     |> assign(:current_user, current_user)
     |> assign(:current_scope, if(current_user, do: current_user.role, else: nil))
     |> assign(:categories, categories)
     |> assign(:selected_category_id, nil)
     |> assign(:region, "")
     |> assign(:province_filter, "")
     |> assign(:city_filter, "")
     |> assign(:custom_location, "")
     |> assign(:show_login_prompt, false)
     |> assign(:profiles, [])
     |> assign(:user_lat, nil)
     |> assign(:user_lng, nil)
     |> assign(:search, "")
     |> load_profiles()}
  end

  defp load_profiles(socket) do
    opts = [approved_only: true]

    opts =
      case socket.assigns[:selected_category_id] do
        nil -> opts
        id -> Keyword.put(opts, :skill_category_id, id)
      end

    # Region search: combine province, city, custom text, and region text
    search =
      [
        socket.assigns[:province_filter],
        socket.assigns[:city_filter],
        socket.assigns[:custom_location],
        socket.assigns[:region]
      ]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.join(" ")

    opts = if search != "", do: Keyword.put(opts, :region, search), else: opts
    text_search = socket.assigns[:search]

    opts =
      if text_search && text_search != "", do: Keyword.put(opts, :search, text_search), else: opts

    profiles = Skills.list_skilled_profiles(opts)

    socket
    |> assign(:profiles, profiles)
    |> assign(:review_stats, Moderation.review_stats_for_profiles(Enum.map(profiles, & &1.id)))
  end

  defp review_for(stats, profile_id) do
    Map.get(stats, profile_id, %{avg: nil, count: 0})
  end

  @impl true
  def handle_event("select_category", %{"id" => id}, socket) do
    cid = if id == "", do: nil, else: String.to_integer(id)
    {:noreply, socket |> assign(:selected_category_id, cid) |> load_profiles()}
  end

  def handle_event("filter_region", %{"region" => r}, socket) do
    {:noreply, socket |> assign(:region, r) |> load_profiles()}
  end

  def handle_event("filter_province", %{"province" => p}, socket) do
    {:noreply,
     socket |> assign(:province_filter, p) |> assign(:city_filter, "") |> load_profiles()}
  end

  def handle_event("filter_city", %{"city" => c}, socket) do
    {:noreply, socket |> assign(:city_filter, c) |> load_profiles()}
  end

  def handle_event("filter_custom", %{"custom" => v}, socket) do
    {:noreply, socket |> assign(:custom_location, v) |> load_profiles()}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, String.trim(q)) |> load_profiles()}
  end

  def handle_event("clear", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_category_id, nil)
     |> assign(:region, "")
     |> assign(:province_filter, "")
     |> assign(:city_filter, "")
     |> assign(:custom_location, "")
     |> assign(:search, "")
     |> load_profiles()}
  end

  def handle_event("book_click", _, socket) do
    if socket.assigns.current_user do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :show_login_prompt, true)}
    end
  end

  def handle_event("dismiss_prompt", _, socket) do
    {:noreply, assign(socket, :show_login_prompt, false)}
  end

  def handle_event("user_location", %{"lat" => lat, "lng" => lng}, socket) do
    {:noreply, socket |> assign(:user_lat, lat) |> assign(:user_lng, lng)}
  end

  defp cat_icon(slug), do: Map.get(@icons, slug, "🛠️")

  defp haversine(nil, _, _, _), do: nil
  defp haversine(_, nil, _, _), do: nil

  defp haversine(ulat, ulng, wlat, wlng) do
    r = 6371
    dlat = :math.pi() / 180 * (wlat - ulat)
    dlng = :math.pi() / 180 * (wlng - ulng)

    a =
      :math.sin(dlat / 2) ** 2 +
        :math.cos(:math.pi() / 180 * ulat) * :math.cos(:math.pi() / 180 * wlat) *
          :math.sin(dlng / 2) ** 2

    Float.round(r * 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a)), 1)
  end

  defp any_filter?(assigns) do
    assigns.selected_category_id != nil or
      assigns.region != "" or
      assigns.province_filter != "" or
      assigns.city_filter != "" or
      assigns.custom_location != "" or
      assigns.search != ""
  end

  @impl true
  def render(assigns), do: index(assigns)
end
