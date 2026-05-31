defmodule SkillBridgeWeb.HomeLive do
  use SkillBridgeWeb, :live_view
  embed_templates "home_live_html/*"

  import Ecto.Query

  alias SkillBridge.{Accounts, Bookings, Moderation, Repo, Skills}
  alias SkillBridge.Accounts.User
  alias SkillBridge.Skills.SkilledProfile

  @testimonials [
    %{
      name: "Ayesha Khan",
      role: "Homeowner, Lahore",
      image: "/images/logo.svg",
      rating: 5,
      text:
        "Found a verified electrician in minutes. Booking, chat, and payment — everything felt secure and professional."
    },
    %{
      name: "Hassan Ali",
      role: "Small Business Owner",
      image: "/images/logo.svg",
      rating: 5,
      text:
        "SkillBridge helped me hire a plumber and a designer for my shop renovation. Transparent reviews made choosing easy."
    },
    %{
      name: "Sara Malik",
      role: "Skilled Professional",
      image: "/images/logo.svg",
      rating: 5,
      text:
        "As a teacher offering tutoring, I get quality leads and admin verification builds trust with new clients."
    }
  ]

  @extra_categories [
    %{name: "Carpenter", slug: "carpenter", icon: "🪚"},
    %{name: "Designer", slug: "designer", icon: "🎨"},
    %{name: "Tailor", slug: "tailor", icon: "🧵"}
  ]

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)

    if user do
      destination =
        case user.role do
          "admin" -> "/admin"
          "skilled_person" -> "/skilled"
          _ -> "/user"
        end

      {:ok, push_navigate(socket, to: destination)}
    else
      categories = Skills.list_skill_categories()
      display_categories = merge_display_categories(categories)

      featured =
        Skills.list_skilled_profiles(approved_only: true)
        |> Enum.take(6)

      review_stats = Moderation.review_stats_for_profiles(Enum.map(featured, & &1.id))

      {:ok,
       socket
       |> assign(:page_title, "SkillBridge — Connect. Work. Grow.")
       |> assign(:current_scope, nil)
       |> assign(:current_user, nil)
       |> assign(:categories, categories)
       |> assign(:display_categories, display_categories)
       |> assign(:featured_workers, featured)
       |> assign(:review_stats, review_stats)
       |> assign(:testimonials, @testimonials)
       |> assign(:platform_stats, platform_stats())}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp platform_stats do
    workers =
      SkilledProfile
      |> where([p], p.status == "approved" and not is_nil(p.approved_at))
      |> Repo.aggregate(:count, :id)

    clients =
      User
      |> where([u], u.role == "user")
      |> Repo.aggregate(:count, :id)

    jobs = Repo.aggregate(Bookings.Booking, :count, :id)

    %{
      workers: display_stat(workers, 10_000),
      clients: display_stat(clients, 5_000),
      jobs: display_stat(jobs, 20_000),
      satisfaction: 95
    }
  end

  defp display_stat(actual, floor) when actual >= floor, do: actual
  defp display_stat(actual, _floor) when actual > 0, do: actual
  defp display_stat(_actual, floor), do: floor

  defp merge_display_categories(categories) do
    existing_slugs = MapSet.new(categories, & &1.slug)

    extra =
      Enum.reject(@extra_categories, fn c -> MapSet.member?(existing_slugs, c.slug) end)

    Enum.map(categories, fn c ->
      %{name: c.name, slug: c.slug, icon: category_icon(c.slug), href: ~p"/browse"}
    end) ++
      Enum.map(extra, fn c ->
        Map.put(c, :href, ~p"/browse")
      end)
  end

  def category_icon("electrician"), do: "⚡"
  def category_icon("plumber"), do: "🔧"
  def category_icon("mechanic"), do: "🔩"
  def category_icon("civil_engineer"), do: "🏗️"
  def category_icon("architect"), do: "🏛️"
  def category_icon("software_engineer"), do: "💻"
  def category_icon("teacher"), do: "📚"
  def category_icon("carpenter"), do: "🪚"
  def category_icon("designer"), do: "🎨"
  def category_icon("tailor"), do: "🧵"
  def category_icon(_), do: "🛠️"

  def review_for(stats, id), do: Map.get(stats, id, %{avg: nil, count: 0})

  def worker_initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  @impl true
  def handle_event("newsletter", %{"email" => email}, socket) do
    {:noreply, put_flash(socket, :info, "Thanks! We'll keep #{email} updated.")}
  end

  @impl true
  def render(assigns), do: index(assigns)
end
