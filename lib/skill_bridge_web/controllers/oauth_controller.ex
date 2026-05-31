defmodule SkillBridgeWeb.OAuthController do
  use SkillBridgeWeb, :controller

  alias SkillBridge.{Accounts, OAuth, Skills}
  alias SkillBridgeWeb.Plugs.Auth

  def google(conn, params) do
    role = if params["role"] in ["user", "skilled_person"], do: params["role"], else: "user"

    if OAuth.configured?() do
      redirect_uri = url(conn, ~p"/auth/callback")

      conn
      |> put_session(:oauth_role, role)
      |> redirect(external: OAuth.google_authorize_url(redirect_uri, role))
    else
      conn
      |> put_flash(
        :error,
        "Google sign-in is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY."
      )
      |> redirect(to: ~p"/login")
    end
  end

  def callback(conn, %{"code" => code} = params) do
    redirect_uri = url(conn, ~p"/auth/callback")
    role = oauth_role(conn, params)

    with {:ok, supa_user, _token} <- OAuth.exchange_code_and_fetch_user(code, redirect_uri),
         {:ok, user} <- upsert_user(supa_user, role) do
      if user.role == "skilled_person", do: Skills.ensure_skilled_profile_for_user(user.id)

      conn
      |> Auth.log_in_user(user)
      |> delete_session(:oauth_role)
      |> put_flash(:info, "Signed in with Google.")
      |> redirect(to: home_path(user))
    else
      {:error, _} ->
        conn
        |> put_flash(:error, "Google sign-in failed. Please try email and password.")
        |> redirect(to: ~p"/login")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Google sign-in was cancelled or incomplete.")
    |> redirect(to: ~p"/login")
  end

  defp oauth_role(conn, params) do
    case decode_state(params["state"]) do
      {:ok, %{"role" => role}} when role in ["user", "skilled_person"] -> role
      _ -> get_session(conn, :oauth_role) || "user"
    end
  end

  defp decode_state(nil), do: :error

  defp decode_state(state) do
    with {:ok, json} <- Base.url_decode64(state, padding: false),
         {:ok, map} <- Jason.decode(json) do
      {:ok, map}
    else
      _ -> :error
    end
  end

  defp upsert_user(%{"id" => uid, "email" => email} = body, role) do
    name =
      body["user_metadata"]["full_name"] ||
        body["user_metadata"]["name"] ||
        email
        |> String.split("@")
        |> List.first()
        |> String.capitalize()

    Accounts.find_or_create_oauth_user(%{
      email: email,
      name: name,
      oauth_uid: uid,
      oauth_provider: "google",
      role: role
    })
  end

  defp upsert_user(_, _), do: {:error, :invalid_user}

  defp home_path(%{role: "admin"}), do: ~p"/admin"
  defp home_path(%{role: "skilled_person"}), do: ~p"/skilled"
  defp home_path(_), do: ~p"/user"
end
