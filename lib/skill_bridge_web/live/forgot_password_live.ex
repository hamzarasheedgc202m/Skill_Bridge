defmodule SkillBridgeWeb.ForgotPasswordLive do
  use SkillBridgeWeb, :live_view
  alias SkillBridge.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Forgot Password")
     |> assign(:current_user, nil)
     |> assign(:current_scope, nil)
     |> assign(:email, "")
     |> assign(:submitted, false)}
  end

  @impl true
  def handle_event("set_email", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :email, v)}

  def handle_event("submit", _, socket) do
    Accounts.request_password_reset(String.trim(socket.assigns.email))
    {:noreply, assign(socket, :submitted, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="max-w-md mx-auto mt-16">
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-8">
          <h1 class="text-2xl font-bold text-gray-900 mb-1">Forgot password?</h1>
          <p class="text-sm text-gray-500 mb-6">Enter your email and we'll send a reset link.</p>

          <%= if @submitted do %>
            <div class="bg-emerald-50 border border-emerald-100 rounded-xl p-4 text-sm text-emerald-700">
              ✓ If that email is registered, a reset link has been sent. Check your inbox.
            </div>
            <.link
              navigate={~p"/login"}
              class="block mt-4 text-center text-sm text-slate-600 hover:underline"
            >
              Back to login
            </.link>
          <% else %>
            <input
              type="email"
              phx-keyup="set_email"
              phx-value-value=""
              placeholder="your@email.com"
              value={@email}
              class="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-slate-200 mb-4"
            />
            <button
              phx-click="submit"
              class="w-full py-2.5 bg-slate-800 text-white rounded-xl text-sm font-semibold hover:bg-slate-700 transition-all"
            >
              Send Reset Link
            </button>
            <.link
              navigate={~p"/login"}
              class="block mt-3 text-center text-sm text-gray-400 hover:underline"
            >
              Back to login
            </.link>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
