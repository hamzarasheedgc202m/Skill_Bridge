defmodule SkillBridge.OAuth do
  @moduledoc """
  Supabase Google OAuth helpers. Requires `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
  """
  @provider "google"

  def configured? do
    supabase_url() not in [nil, ""] and supabase_anon_key() not in [nil, ""]
  end

  def google_authorize_url(redirect_uri, role \\ "user")
      when role in ["user", "skilled_person"] do
    base = String.trim_trailing(supabase_url(), "/")
    state = Base.url_encode64(Jason.encode!(%{role: role}), padding: false)

    query =
      URI.encode_query(%{
        provider: @provider,
        redirect_to: redirect_uri,
        state: state
      })

    "#{base}/auth/v1/authorize?#{query}"
  end

  @doc "Exchange OAuth authorization code for user profile via Supabase."
  def exchange_code_and_fetch_user(code, redirect_uri) do
    base = String.trim_trailing(supabase_url(), "/")

    with {:ok, %{"access_token" => token}} <-
           post_token("#{base}/auth/v1/token?grant_type=authorization_code", %{
             code: code,
             redirect_uri: redirect_uri
           }),
         {:ok, user} <- fetch_user(token) do
      {:ok, user, token}
    end
  end

  defp fetch_user(access_token) do
    base = String.trim_trailing(supabase_url(), "/")

    case Req.get("#{base}/auth/v1/user",
           headers: [
             {"apikey", supabase_anon_key()},
             {"Authorization", "Bearer #{access_token}"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:supabase_user, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post_token(url, params) do
    case Req.post(url,
           headers: [
             {"apikey", supabase_anon_key()},
             {"Content-Type", "application/json"}
           ],
           json: params
         ) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:supabase_token, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp supabase_url do
    Application.get_env(:skill_bridge, :supabase, [])[:url] ||
      System.get_env("SUPABASE_URL")
  end

  defp supabase_anon_key do
    Application.get_env(:skill_bridge, :supabase, [])[:anon_key] ||
      System.get_env("SUPABASE_ANON_KEY")
  end
end
