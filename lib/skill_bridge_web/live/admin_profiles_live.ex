defmodule SkillBridgeWeb.AdminProfilesLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_profiles_live_html/*"
  alias SkillBridge.Accounts

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)

    {:ok,
     socket
     |> assign(:page_title, "Profiles")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)}
  end

  defp fetch_user(session) do
    case session[:user_id] || session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    role = params["role"] || ""
    q = params["q"] || ""

    path =
      if role != "" or q != "" do
        ~p"/admin/profiles?#{[role: role, q: q]}"
      else
        ~p"/admin/profiles"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    role = params["role"] || ""
    q = params["q"] || ""

    users =
      Accounts.list_users_for_admin(
        role: if(role == "", do: nil, else: role),
        q: if(q == "", do: nil, else: q)
      )

    {:noreply,
     socket
     |> assign(:filter_role, role)
     |> assign(:filter_q, q)
     |> assign(:users, users)}
  end

  defp role_label("skilled_person"), do: "Service provider"
  defp role_label("user"), do: "User"
  defp role_label(other), do: other

  defp location_label(u) do
    [u.province, u.district, u.city]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
    |> case do
      "" -> "—"
      s -> s
    end
  end

  defp profile_thumb(u) do
    cond do
      is_binary(u.profile_image_path) and u.profile_image_path != "" ->
        u.profile_image_path

      u.skilled_profile && is_binary(u.skilled_profile.profile_image_url) &&
          u.skilled_profile.profile_image_url != "" ->
        u.skilled_profile.profile_image_url

      true ->
        ""
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
