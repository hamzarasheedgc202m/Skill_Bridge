defmodule SkillBridgeWeb.Plugs.RequireAuth do
  @moduledoc """
  Redirects unauthenticated requests to /login.
  Also blocks frozen accounts from accessing any protected area.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/login")
        |> halt()

      not is_nil(user.frozen_at) ->
        conn
        |> Phoenix.Controller.put_flash(
          :error,
          "Your account has been frozen by an administrator. Please contact support."
        )
        |> redirect(to: "/")
        |> halt()

      true ->
        conn
    end
  end
end
