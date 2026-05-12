defmodule SkillBridge.Accounts do
  @moduledoc """
  Context for user accounts and authentication.
  """
  import Ecto.Query
  alias SkillBridge.Repo
  alias SkillBridge.Accounts.User
  alias SkillBridge.Accounts.PasswordResetToken

  def get_user!(id), do: Repo.get!(User, id)
  def get_user(id), do: Repo.get(User, id)
  def get_user_by_email(email), do: Repo.get_by(User, email: String.downcase(email))

  def register_user(attrs) do
    role = attrs["role"] || attrs[:role]

    if role == "admin" do
      changeset =
        %User{}
        |> User.changeset(attrs)
        |> Ecto.Changeset.add_error(
          :role,
          "Admin accounts cannot be created through registration."
        )

      {:error, changeset}
    else
      %User{} |> User.changeset(attrs) |> Repo.insert()
    end
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    if user && Bcrypt.verify_pass(password, user.password_hash),
      do: {:ok, user},
      else: {:error, :invalid_credentials}
  end

  def list_users_by_role(role) do
    User |> where([u], u.role == ^role) |> Repo.all()
  end

  def list_admins, do: list_users_by_role("admin")

  def update_user_profile(%User{} = user, attrs) when is_map(attrs) do
    user |> User.profile_changeset(attrs) |> Repo.update()
  end

  def list_users_for_admin(opts \\ []) do
    role = Keyword.get(opts, :role)
    q = Keyword.get(opts, :q)

    User
    |> where([u], u.role != "admin")
    |> maybe_filter_admin_role(role)
    |> maybe_search_users(q)
    |> order_by([u], desc: u.inserted_at)
    |> preload([:skilled_profile])
    |> Repo.all()
  end

  defp maybe_filter_admin_role(query, nil), do: query
  defp maybe_filter_admin_role(query, ""), do: query
  defp maybe_filter_admin_role(query, role), do: where(query, [u], u.role == ^role)

  defp maybe_search_users(query, nil), do: query
  defp maybe_search_users(query, ""), do: query

  defp maybe_search_users(query, q) do
    term = "%#{String.downcase(q)}%"

    where(
      query,
      [u],
      ilike(u.name, ^term) or
        ilike(u.email, ^term) or
        ilike(coalesce(u.phone, ""), ^term)
    )
  end

  # ── Password Reset ──────────────────────────────────────────────────────────

  def request_password_reset(email) do
    case get_user_by_email(email) do
      nil ->
        {:ok, :sent}

      user ->
        token_string = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

        %PasswordResetToken{}
        |> PasswordResetToken.changeset(%{token: token_string, user_id: user.id})
        |> Repo.insert!()

        SkillBridge.Emails.PasswordResetEmails.password_reset(user, token_string)
        |> SkillBridge.Mailer.deliver()

        {:ok, :sent}
    end
  end

  def get_valid_reset_token(token_string) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-PasswordResetToken.valid_for_hours() * 3600, :second)

    case Repo.get_by(PasswordResetToken, token: token_string) do
      nil ->
        nil

      t when not is_nil(t.used_at) ->
        nil

      t ->
        if DateTime.compare(t.inserted_at, cutoff) == :gt, do: t, else: nil
    end
  end

  def reset_password(token_string, new_password) do
    case get_valid_reset_token(token_string) do
      nil ->
        {:error, :invalid_or_expired}

      token ->
        user = get_user!(token.user_id)

        Ecto.Multi.new()
        |> Ecto.Multi.update(:user, User.password_changeset(user, %{password: new_password}))
        |> Ecto.Multi.update(
          :token,
          Ecto.Changeset.change(token,
            used_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{user: updated_user}} -> {:ok, updated_user}
          {:error, _, changeset, _} -> {:error, changeset}
        end
    end
  end

  @doc """
  Finds or creates a user from a Google/Supabase OAuth callback.

  Lookup order:
    1. Find by oauth_uid + oauth_provider (exact match)
    2. Find by email (link existing account)
    3. Create new user

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def find_or_create_oauth_user(%{
        email: email,
        name: name,
        oauth_uid: uid,
        oauth_provider: provider,
        role: role
      }) do
    email = String.downcase(email)

    # 1. Find by oauth uid
    existing_by_uid =
      User
      |> where([u], u.oauth_provider == ^provider and u.oauth_uid == ^uid)
      |> Repo.one()

    cond do
      existing_by_uid ->
        {:ok, existing_by_uid}

      user = Repo.get_by(User, email: email) ->
        # Link existing account to Google
        user
        |> User.oauth_changeset(%{
          email: email,
          name: user.name,
          role: user.role,
          oauth_provider: provider,
          oauth_uid: uid
        })
        |> Repo.update()

      true ->
        # Create new user — no password needed for OAuth
        %User{}
        |> User.oauth_changeset(%{
          email: email,
          name: name,
          role: role,
          oauth_provider: provider,
          oauth_uid: uid
        })
        |> Repo.insert()
    end
  end
end
