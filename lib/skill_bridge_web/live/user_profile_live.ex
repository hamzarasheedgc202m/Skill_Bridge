defmodule SkillBridgeWeb.UserProfileLive do
  use SkillBridgeWeb, :live_view
  embed_templates "user_profile_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Accounts.User
  alias SkillBridge.PakistanLocations
  alias SkillBridge.Repo

  @max_image_bytes 5 * 1024 * 1024
  @max_data_url 2_500_000

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    province = user.province || ""
    district = user.district || ""

    {:ok,
     socket
     |> assign(:page_title, "My Profile")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:saving, false)
     |> assign(:province, province)
     |> assign(:district, district)
     |> assign(:districts, PakistanLocations.districts(province))
     |> assign(:tehsils, PakistanLocations.tehsils(province, district))
     |> assign(:cities, PakistanLocations.cities(province, district))
     |> assign(:form, build_form(user))
     |> assign(:image_preview, user.profile_image_path || "")
     |> allow_upload(:profile_photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: @max_image_bytes
     )}
  end

  defp fetch_user(session) do
    case session[:user_id] || session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp build_form(user) do
    to_form(
      %{
        "name" => user.name || "",
        "age" => user.age || "",
        "gender" => user.gender || "",
        "education_level" => user.education_level || "",
        "phone" => user.phone || "",
        "province" => user.province || "",
        "district" => user.district || "",
        "tehsil" => user.tehsil || "",
        "city" => user.city || "",
        "profile_image_path" => user.profile_image_path || ""
      },
      as: :user
    )
  end

  @impl true
  def handle_event("province_changed", %{"province_select" => prov}, socket) do
    {:noreply,
     socket
     |> assign(:province, prov)
     |> assign(:district, "")
     |> assign(:districts, PakistanLocations.districts(prov))
     |> assign(:tehsils, [])
     |> assign(:cities, [])}
  end

  def handle_event("district_changed", %{"district_select" => dist}, socket) do
    prov = socket.assigns.province

    {:noreply,
     socket
     |> assign(:district, dist)
     |> assign(:tehsils, PakistanLocations.tehsils(prov, dist))
     |> assign(:cities, PakistanLocations.cities(prov, dist))}
  end

  def handle_event("validate", %{"user" => params} = all_params, socket) do
    prov = Map.get(all_params, "province_select", socket.assigns.province)
    dist = Map.get(all_params, "district_select", socket.assigns.district)

    merged =
      params
      |> Map.put("province", prov)
      |> Map.put("district", dist)
      |> maybe_int("age")

    form =
      socket.assigns.current_user
      |> User.profile_changeset(merged)
      |> Map.put(:action, :validate)
      |> to_form(as: :user)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:province, if(prov != "", do: prov, else: socket.assigns.province))
     |> assign(:district, if(dist != "", do: dist, else: socket.assigns.district))}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end

  def handle_event("save", %{"user" => params} = all_params, socket) do
    socket = assign(socket, :saving, true)
    user = socket.assigns.current_user

    upload_results =
      consume_uploaded_entries(socket, :profile_photo, fn %{path: path}, entry ->
        case SkillBridge.ProfileUpload.save_from_temp(path, entry.client_name) do
          {:ok, public_path} -> {:ok, public_path}
          {:error, _} -> {:ok, nil}
        end
      end)

    uploaded_path = Enum.find_value(upload_results, & &1)

    current = user.profile_image_path || ""

    image_path =
      cond do
        is_binary(uploaded_path) and uploaded_path != "" ->
          uploaded_path

        is_binary(params["profile_image_path"]) and
            String.trim(params["profile_image_path"]) != "" ->
          String.trim(params["profile_image_path"])

        true ->
          current
      end

    prov = Map.get(all_params, "province_select", socket.assigns.province)
    dist = Map.get(all_params, "district_select", socket.assigns.district)

    attrs =
      params
      |> Map.put("province", prov)
      |> Map.put("district", dist)
      |> Map.put("profile_image_path", image_path)
      |> maybe_int("age")

    cond do
      image_path == "" ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> put_flash(
           :error,
           "Profile photo is required. Please upload a photo to continue."
         )}

      is_binary(image_path) and String.starts_with?(image_path, "data:") and
          byte_size(image_path) > @max_data_url ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> put_flash(:error, "Image data is too large. Please upload a file instead.")}

      true ->
        cs = User.profile_changeset(user, attrs)

        if cs.valid? do
          case Repo.update(cs) do
            {:ok, u} ->
              {:noreply,
               socket
               |> assign(:current_user, u)
               |> assign(:form, User.profile_changeset(u, %{}) |> to_form(as: :user))
               |> assign(:saving, false)
               |> assign(:image_preview, image_path)
               |> put_flash(:info, "Profile saved.")}

            {:error, invalid} ->
              {:noreply,
               socket
               |> assign(:saving, false)
               |> assign(:form, to_form(invalid, as: :user))
               |> put_flash(:error, "Please fix the errors below.")}
          end
        else
          {:noreply,
           socket
           |> assign(:saving, false)
           |> assign(:form, to_form(cs, as: :user))
           |> put_flash(:error, "Please fix the errors below.")}
        end
    end
  end

  defp maybe_int(attrs, "age" = key) do
    case attrs[key] do
      "" ->
        Map.put(attrs, key, nil)

      nil ->
        attrs

      v when is_binary(v) ->
        case Integer.parse(v) do
          {n, _} -> Map.put(attrs, key, n)
          :error -> attrs
        end

      _ ->
        attrs
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
