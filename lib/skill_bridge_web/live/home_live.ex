defmodule SkillBridgeWeb.HomeLive do
  use SkillBridgeWeb, :live_view
  embed_templates "home_live_html/*"
  alias SkillBridge.Skills
  alias SkillBridge.Accounts

  @impl true
  def mount(_params, session, socket) do
    categories = Skills.list_skill_categories()
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
      {:ok,
       socket
       |> assign(:page_title, "SkillBridge — Hire Skilled Professionals")
       |> assign(:current_scope, nil)
       |> assign(:current_user, nil)
       |> assign(:categories, categories)}
    end
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp category_icon("electrician"), do: "⚡"
  defp category_icon("plumber"), do: "🔧"
  defp category_icon("mechanic"), do: "🔩"
  defp category_icon("civil_engineer"), do: "🏗️"
  defp category_icon("architect"), do: "🏛️"
  defp category_icon("software_engineer"), do: "💻"
  defp category_icon("teacher"), do: "📚"
  defp category_icon(_), do: "🛠️"

  @impl true
  def render(assigns), do: index(assigns)
end
