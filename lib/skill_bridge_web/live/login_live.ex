defmodule SkillBridgeWeb.LoginLive do
  use SkillBridgeWeb, :live_view
  embed_templates "login_live_html/*"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sign In — SkillBridge")
     |> assign(:current_scope, nil)
     |> assign(:current_user, nil)
     |> assign(:oauth_enabled, SkillBridge.OAuth.configured?())
     |> assign(:show_password, false)
     |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: :user))}
  end

  @impl true
  def handle_event("toggle_password", _, socket) do
    {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}
  end

  @impl true
  def handle_event("sync_form", %{"user" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :user))}
  end

  @impl true
  def render(assigns), do: index(assigns)
end
