defmodule SkillBridgeWeb.Plugs.RequireScope do
  @moduledoc """
  Ensures current_scope is in the allowed list. Use after Auth and RequireAuth.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, opts) do
    allowed = Keyword.fetch!(opts, :allowed)
    scope = conn.assigns[:current_scope]

    if scope in allowed do
      conn
    else
      message =
        if "admin" in allowed do
          "Access denied. This area is restricted to administrators only."
        else
          "You do not have access to this area."
        end

      conn
      |> put_flash(:error, message)
      |> redirect(to: "/")
      |> halt()
    end
  end
end
