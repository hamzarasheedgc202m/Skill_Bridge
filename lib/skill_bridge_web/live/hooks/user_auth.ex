defmodule SkillBridgeWeb.Live.Hooks.UserAuth do
  @moduledoc """
  on_mount hook that re-checks frozen status on every LiveView mount/reconnect.
  Wire into router.ex live_session blocks to protect all scoped LiveViews.
  """
  import Phoenix.LiveView
  alias SkillBridge.Accounts

  def on_mount(:ensure_not_frozen, _params, session, socket) do
    user =
      case session["user_id"] do
        nil -> nil
        id -> Accounts.get_user(id)
      end

    cond do
      is_nil(user) ->
        {:halt, push_navigate(socket, to: "/login")}

      not is_nil(user.frozen_at) ->
        socket =
          socket
          |> put_flash(:error, "Your account has been frozen. Please contact support.")
          |> push_navigate(to: "/")

        {:halt, socket}

      true ->
        {:cont, socket}
    end
  end
end
