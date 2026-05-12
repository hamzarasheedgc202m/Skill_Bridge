defmodule SkillBridgeWeb.RegisterLive do
  use SkillBridgeWeb, :live_view
  embed_templates "register_live_html/*"
  alias SkillBridge.Accounts

  @roles [
    {"User — hire skilled persons", "user"},
    {"Skilled Person — offer my services", "skilled_person"}
  ]

  @impl true
  def mount(params, _session, socket) do
    default_role = Map.get(params, "role", "user")

    {:ok,
     socket
     |> assign(:page_title, "Create Account — SkillBridge")
     |> assign(:current_scope, nil)
     |> assign(:current_user, nil)
     |> assign(:roles, @roles)
     |> assign(:show_password, false)
     |> assign(:loading, false)
     |> assign(
       :form,
       to_form(%{"email" => "", "name" => "", "password" => "", "role" => default_role},
         as: :user
       )
     )}
  end

  @impl true
  def handle_event("toggle_password", _, socket) do
    {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      %Accounts.User{}
      |> Accounts.User.changeset(params)
      |> Ecto.Changeset.apply_action(:insert)
      |> case do
        {:ok, _} -> to_form(params, as: :user)
        {:error, cs} -> to_form(cs, as: :user)
      end

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    {:noreply, assign(socket, :loading, true)}

    case Accounts.register_user(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:info, "Account created successfully! Please log in.")
         |> push_navigate(to: ~p"/login")}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:form, to_form(cs, as: :user))}
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
