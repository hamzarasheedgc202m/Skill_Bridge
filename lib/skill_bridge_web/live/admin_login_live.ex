defmodule SkillBridgeWeb.AdminLoginLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_login_live_html/*"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Portal — SkillBridge")
     |> assign(:current_scope, nil)
     |> assign(:current_user, nil)
     |> assign(:show_password, false)
     |> assign(:show_key, false)}
  end

  @impl true
  def handle_event("toggle_password", _, socket),
    do: {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}

  def handle_event("toggle_key", _, socket),
    do: {:noreply, assign(socket, :show_key, !socket.assigns.show_key)}

  @impl true
  def render(assigns), do: index(assigns)
end
