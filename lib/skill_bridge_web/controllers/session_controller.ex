defmodule SkillBridgeWeb.SessionController do
  use SkillBridgeWeb, :controller
  alias SkillBridge.Accounts
  alias SkillBridge.Moderation
  alias SkillBridgeWeb.Plugs.Auth

  # ── Admin portal login ────────────────────────────────────────────────────
  def create(conn, %{"admin_portal" => "1", "user" => params}) do
    email = params["email"] || ""
    pw = params["password"] || ""
    key = params["admin_key"] || ""

    with {:creds, {:ok, user}} <- {:creds, Accounts.authenticate_user(email, pw)},
         {:role, true} <- {:role, user.role == "admin"},
         {:key, true} <- {:key, Moderation.verify_admin_key(key)} do
      conn
      |> Auth.log_in_user(user)
      |> put_flash(:info, "Welcome, #{user.name}. Admin session started.")
      |> redirect(to: ~p"/admin")
    else
      {:creds, _} ->
        conn |> put_flash(:error, "Invalid email or password.") |> redirect(to: ~p"/admin/login")

      {:role, _} ->
        conn
        |> put_flash(:error, "This account does not have admin privileges.")
        |> redirect(to: ~p"/admin/login")

      {:key, _} ->
        conn
        |> put_flash(:error, "Invalid admin secret key. Contact your system administrator.")
        |> redirect(to: ~p"/admin/login")
    end
  end

  # ── Regular login ─────────────────────────────────────────────────────────
  def create(conn, %{"user" => %{"email" => email, "password" => password} = _params})
      when is_binary(email) and is_binary(password) and email != "" and password != "" do
    case Accounts.authenticate_user(String.trim(email), password) do
      {:ok, %{role: "admin"}} ->
        conn
        |> put_flash(:error, "Admin accounts must use the Admin Portal login.")
        |> redirect(to: ~p"/admin/login")

      {:ok, user} ->
        conn
        |> Auth.log_in_user(user)
        |> put_flash(:info, "Welcome back, #{user.name}!")
        |> redirect(to: redirect_path(user))

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid email or password. Check your details and try again.")
        |> redirect(to: ~p"/login")
    end
  end

  def create(conn, %{"user" => params}) when is_map(params) do
    email = to_string(params["email"] || "")
    password = to_string(params["password"] || "")

    if String.trim(email) == "" or password == "" do
      conn
      |> put_flash(:error, "Please enter both your email and password.")
      |> redirect(to: ~p"/login")
    else
      create(
        conn,
        %{"user" => %{"email" => email, "password" => password}}
      )
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Please use the sign-in form with a valid email and password.")
    |> redirect(to: ~p"/login")
  end

  def delete(conn, _params) do
    conn
    |> Auth.log_out_user()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end

  defp redirect_path(%{role: "skilled_person"}), do: ~p"/skilled"
  defp redirect_path(_), do: ~p"/user"
end
