defmodule SkillBridgeWeb.ResetPasswordLive do
  use SkillBridgeWeb, :live_view
  alias SkillBridge.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    valid = Accounts.get_valid_reset_token(token)

    {:ok,
     socket
     |> assign(:page_title, "Reset Password")
     |> assign(:current_user, nil)
     |> assign(:current_scope, nil)
     |> assign(:token, token)
     |> assign(:valid_token, not is_nil(valid))
     |> assign(:password, "")
     |> assign(:password_confirm, "")
     |> assign(:done, false)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("set_password", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :password, v)}

  def handle_event("set_confirm", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :password_confirm, v)}

  def handle_event("submit", _, socket) do
    pw = String.trim(socket.assigns.password)
    cfm = String.trim(socket.assigns.password_confirm)

    cond do
      String.length(pw) < 8 ->
        {:noreply, assign(socket, :error, "Password must be at least 8 characters.")}

      pw != cfm ->
        {:noreply, assign(socket, :error, "Passwords do not match.")}

      true ->
        case Accounts.reset_password(socket.assigns.token, pw) do
          {:ok, _} ->
            {:noreply, assign(socket, :done, true)}

          {:error, :invalid_or_expired} ->
            {:noreply, assign(socket, :error, "Token is invalid or expired. Request a new link.")}

          {:error, _cs} ->
            {:noreply, assign(socket, :error, "Could not reset password. Please try again.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="max-w-md mx-auto mt-16">
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-8">
          <h1 class="text-2xl font-bold text-gray-900 mb-1">Reset Password</h1>

          <%= cond do %>
            <% @done -> %>
              <div class="bg-emerald-50 border border-emerald-100 rounded-xl p-4 text-sm text-emerald-700 mb-4">
                ✓ Password updated successfully!
              </div>
              <.link
                navigate={~p"/login"}
                class="block text-center text-sm text-slate-600 hover:underline"
              >
                Log in with your new password
              </.link>
            <% not @valid_token -> %>
              <div class="bg-red-50 border border-red-100 rounded-xl p-4 text-sm text-red-600 mb-4">
                This reset link is invalid or has expired.
              </div>
              <.link
                navigate={~p"/forgot-password"}
                class="block text-center text-sm text-slate-600 hover:underline"
              >
                Request a new link
              </.link>
            <% true -> %>
              <%= if @error do %>
                <div class="bg-red-50 border border-red-100 rounded-xl p-3 text-sm text-red-600 mb-4">
                  {@error}
                </div>
              <% end %>
              <div class="space-y-3 mb-4">
                <input
                  type="password"
                  phx-keyup="set_password"
                  placeholder="New password (min 8 chars)"
                  value={@password}
                  class="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-slate-200"
                />
                <input
                  type="password"
                  phx-keyup="set_confirm"
                  placeholder="Confirm new password"
                  value={@password_confirm}
                  class="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-slate-200"
                />
              </div>
              <button
                phx-click="submit"
                class="w-full py-2.5 bg-slate-800 text-white rounded-xl text-sm font-semibold hover:bg-slate-700 transition-all"
              >
                Set New Password
              </button>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
