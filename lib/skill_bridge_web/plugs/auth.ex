defmodule SkillBridgeWeb.Plugs.Auth do
  @moduledoc """
  Session-based auth: fetches current user and assigns current_scope for role-based routes.
  """
  import Plug.Conn
  alias SkillBridge.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = if user_id, do: Accounts.get_user(user_id), else: nil
    scope = if user, do: user.role, else: nil

    assign(conn, :current_user, user)
    |> assign(:current_scope, scope)
  end

  def log_in_user(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
  end

  def log_out_user(conn) do
    conn
    |> configure_session(drop: true)
    |> clear_session()
  end
end
