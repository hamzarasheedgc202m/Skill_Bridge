defmodule SkillBridgeWeb.SkilledProfileLive do
  use SkillBridgeWeb, :live_view
  embed_templates "skilled_profile_live_html/*"
  alias Ecto.Multi
  alias SkillBridge.Accounts
  alias SkillBridge.Accounts.User
  alias SkillBridge.Location
  alias SkillBridge.Repo
  alias SkillBridge.Skills
  alias SkillBridge.Skills.SkilledProfile
  alias SkillBridge.PakistanLocations
  alias SkillBridge.ProfileUpload

  @max_image_bytes 5 * 1024 * 1024

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    profile = Skills.get_skilled_profile_by_user_id(user.id)
    categories = Skills.list_skill_categories()
    location = if profile, do: Location.get_worker_location(profile.id), else: nil

    province = (profile && profile.province) || ""
    district = (profile && profile.district) || ""

    completion = Skills.profile_completion(profile)

    {:ok,
     socket
     |> assign(:page_title, "My Profile")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:profile, profile)
     |> assign(:categories, categories)
     |> assign(:saving, false)
     |> assign(:image_error, nil)
     |> assign(:image_preview, image_preview_for(user, profile))
     |> assign(:province, province)
     |> assign(:district, district)
     |> assign(:districts, PakistanLocations.districts(province))
     |> assign(:tehsils, PakistanLocations.tehsils(province, district))
     |> assign(:cities, PakistanLocations.cities(province, district))
     |> assign(:pin_lat, location && location.latitude)
     |> assign(:pin_lng, location && location.longitude)
     |> assign(:location_label, nil)
     |> assign(:form, build_initial_form(profile, user))
     |> assign(:completion, completion)
     |> assign(:onboarding_steps, onboarding_steps(completion))
     |> allow_upload(:profile_photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: @max_image_bytes
     )}
  end

  # ── Form helpers ───────────────────────────────────────────────────────────

  defp build_initial_form(nil, user) do
    to_form(
      %{
        "skill_category_id" => "",
        "bio" => "",
        "hourly_rate_cents" => "",
        "province" => "",
        "district" => "",
        "tehsil" => "",
        "city" => "",
        "region" => "",
        "profile_image_url" => "",
        "age" => user.age || "",
        "gender" => user.gender || "",
        "education_level" => user.education_level || "",
        "phone" => user.phone || ""
      },
      as: :profile
    )
  end

  defp build_initial_form(%SkilledProfile{} = profile, user) do
    extras =
      %{
        "age" => profile.age || user.age,
        "gender" => profile.gender || user.gender,
        "education_level" => profile.education_level || user.education_level,
        "phone" => profile.phone || user.phone
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    profile
    |> SkilledProfile.changeset(extras)
    |> then(&to_form(&1, as: :profile))
  end

  defp fetch_user(session) do
    case session[:user_id] || session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  defp image_preview_for(user, profile) do
    cond do
      profile && profile.profile_image_url && profile.profile_image_url != "" ->
        profile.profile_image_url

      user.profile_image_path && user.profile_image_path != "" ->
        user.profile_image_path

      true ->
        ""
    end
  end

  # ── Location cascade ───────────────────────────────────────────────────────

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

  # ── Image handling ─────────────────────────────────────────────────────────
  # NOTE: base64 data-URLs are no longer stored in the DB.
  # If user pastes a data-URL in the URL field we save it to disk immediately.

  def handle_event("image_url_change", %{"profile" => %{"profile_image_url" => url}}, socket) do
    url = String.trim(url)

    cond do
      # User pasted a data-URL — save to disk right away, show preview
      String.starts_with?(url, "data:") ->
        case ProfileUpload.save_from_base64(url) do
          {:ok, path} ->
            {:noreply,
             socket
             |> assign(:image_preview, path)
             |> assign(:image_error, nil)
             |> assign(:pasted_image_path, path)}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(
               :image_error,
               "Could not process pasted image. Try uploading a file instead."
             )}
        end

      # Normal https:// URL — just preview it
      url != "" ->
        {:noreply,
         socket
         |> assign(:image_preview, url)
         |> assign(:image_error, nil)
         |> assign(:pasted_image_path, nil)}

      true ->
        {:noreply, socket |> assign(:image_preview, "") |> assign(:pasted_image_path, nil)}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end

  # ── Map pin ────────────────────────────────────────────────────────────────

  def handle_event("update_location", %{"lat" => lat, "lng" => lng}, socket) do
    {flat, flng} = Location.fuzz_coordinates(lat, lng)

    {:noreply,
     socket
     |> assign(:pin_lat, flat)
     |> assign(:pin_lng, flng)
     |> push_event("location:set_marker", %{lat: flat, lng: flng})}
  end

  def handle_event("location_selected", params, socket) do
    label =
      [params["city"], params["state"], params["country"]]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.join(", ")

    {:noreply, assign(socket, :location_label, label)}
  end

  def handle_event("detect_location_pin", _, socket) do
    {:noreply, push_event(socket, "location:detect", %{})}
  end

  def handle_event("location_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  # ── Validate ───────────────────────────────────────────────────────────────

  def handle_event("validate", %{"profile" => params} = all_params, socket) do
    prov = Map.get(all_params, "province_select", socket.assigns.province)
    dist = Map.get(all_params, "district_select", socket.assigns.district)
    profile = socket.assigns.profile || %SkilledProfile{user_id: socket.assigns.current_user.id}

    merged =
      params
      |> Map.put("user_id", to_string(socket.assigns.current_user.id))
      |> Map.put("province", prov)
      |> Map.put("district", dist)
      |> maybe_int("skill_category_id")
      |> maybe_int("hourly_rate_cents")
      |> maybe_int("age")

    form =
      profile
      |> SkilledProfile.full_changeset(merged)
      |> Map.put(:action, :validate)
      |> to_form(as: :profile)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:province, if(prov != "", do: prov, else: socket.assigns.province))
     |> assign(:district, if(dist != "", do: dist, else: socket.assigns.district))}
  end

  # ── Save ───────────────────────────────────────────────────────────────────

  def handle_event("save", %{"profile" => params} = all_params, socket) do
    socket = assign(socket, :saving, true)
    user = socket.assigns.current_user
    profile = socket.assigns.profile

    # 1. Try LiveView file upload first (highest priority)
    upload_results =
      consume_uploaded_entries(socket, :profile_photo, fn %{path: path}, entry ->
        case ProfileUpload.save_from_temp(path, entry.client_name) do
          {:ok, public_path} -> {:ok, public_path}
          {:error, _} -> {:ok, nil}
        end
      end)

    uploaded_path = Enum.find_value(upload_results, & &1)

    # 2. Previously saved pasted data-URL path
    pasted_path = socket.assigns[:pasted_image_path]

    # 3. URL typed/pasted in the URL field (must be https://, not data:)
    url_field =
      case String.trim(params["profile_image_url"] || "") do
        "" ->
          nil

        u ->
          if String.starts_with?(u, "data:"),
            # already handled in image_url_change
            do: nil,
            else: u
      end

    # 4. Existing image already on this profile
    current_image = image_preview_for(user, profile)

    # Priority: new upload > pasted data-url > typed URL > existing
    image_path =
      cond do
        is_binary(uploaded_path) and uploaded_path != "" -> uploaded_path
        is_binary(pasted_path) and pasted_path != "" -> pasted_path
        is_binary(url_field) and url_field != "" -> url_field
        true -> current_image
      end

    if image_path == "" do
      {:noreply,
       socket
       |> assign(:saving, false)
       |> put_flash(:error, "A profile photo is required — upload a file or paste an image URL.")}
    else
      prov = Map.get(all_params, "province_select", socket.assigns.province)
      dist = Map.get(all_params, "district_select", socket.assigns.district)

      profile_attrs =
        params
        |> Map.put("user_id", user.id)
        |> Map.put("province", prov)
        |> Map.put("district", dist)
        |> Map.put("profile_image_url", image_path)
        |> maybe_int("skill_category_id")
        |> maybe_int("hourly_rate_cents")
        |> maybe_int("age")
        |> set_region()

      user_params = Map.get(all_params, "user", %{})

      user_attrs = %{
        "name" => user_params["name"] || user.name,
        "age" => profile_attrs["age"],
        "gender" => profile_attrs["gender"],
        "education_level" => profile_attrs["education_level"],
        "phone" => profile_attrs["phone"],
        "province" => prov,
        "district" => dist,
        "tehsil" => profile_attrs["tehsil"],
        "city" => profile_attrs["city"],
        "profile_image_path" => image_path
      }

      user_cs = User.profile_changeset(user, user_attrs)
      profile_cs = (profile || %SkilledProfile{}) |> SkilledProfile.full_changeset(profile_attrs)

      if user_cs.valid? && profile_cs.valid? do
        multi =
          Multi.new()
          |> Multi.update(:user, user_cs)
          |> Multi.run(:profile, fn repo, %{user: u} ->
            attrs = Map.put(profile_attrs, "user_id", u.id)
            struct = profile || %SkilledProfile{}
            cs = SkilledProfile.full_changeset(struct, attrs)
            if struct.id, do: repo.update(cs), else: repo.insert(cs)
          end)

        case Repo.transaction(multi) do
          {:ok, %{user: u, profile: p}} ->
            p = Repo.preload(p, [:skill_category, :availability_slots, :user])
            _ = maybe_store_pin_location(p, socket.assigns.pin_lat, socket.assigns.pin_lng)
            new_completion = Skills.profile_completion(p)

            {:noreply,
             socket
             |> assign(:current_user, u)
             |> assign(:profile, p)
             |> assign(:form, SkilledProfile.changeset(p, %{}) |> to_form(as: :profile))
             |> assign(:saving, false)
             |> assign(:image_preview, image_path)
             |> assign(:pasted_image_path, nil)
             |> assign(:completion, new_completion)
             |> assign(:onboarding_steps, onboarding_steps(new_completion))
             |> put_flash(:info, "Profile saved.")}

          {:error, :profile, cs, _} ->
            {:noreply,
             socket
             |> assign(:saving, false)
             |> assign(:form, to_form(cs, as: :profile))
             |> put_flash(:error, "Please fix the errors below.")}

          {:error, :user, cs, _} ->
            {:noreply,
             socket
             |> assign(:saving, false)
             |> put_flash(:error, format_changeset_errors(cs))}
        end
      else
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:form, to_form(profile_cs, as: :profile))
         |> put_flash(:error, "Please fix the errors below.")}
      end
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  defp format_changeset_errors(cs) do
    cs.errors
    |> Enum.map_join("; ", fn {field, {msg, _opts}} -> "#{field} #{msg}" end)
  end

  defp onboarding_steps(completion) do
    items =
      Map.merge(
        %{
          photo: false,
          personal: false,
          skill_category: false,
          bio: false,
          rate: false,
          city: false,
          location_pin: false,
          availability: false
        },
        completion.items
      )

    [
      %{
        label: "Upload profile photo",
        done: Map.get(items, :photo) == true,
        path: ~p"/skilled/profile"
      },
      %{
        label: "Complete personal details",
        done: Map.get(items, :personal) == true,
        path: ~p"/skilled/profile"
      },
      %{
        label: "Set your map pin",
        done: Map.get(items, :location_pin) == true,
        path: ~p"/skilled/profile"
      },
      %{
        label: "Add skill, rate, and bio",
        done:
          Map.get(items, :skill_category) == true and Map.get(items, :rate) == true and
            Map.get(items, :bio) == true,
        path: ~p"/skilled/profile"
      },
      %{
        label: "Set weekly availability",
        done: Map.get(items, :availability) == true,
        path: ~p"/skilled/availability"
      }
    ]
  end

  defp maybe_store_pin_location(_profile, nil, _lng), do: :ok
  defp maybe_store_pin_location(_profile, _lat, nil), do: :ok

  defp maybe_store_pin_location(profile, lat, lng) do
    with {lat_f, _} <- Float.parse(to_string(lat)),
         {lng_f, _} <- Float.parse(to_string(lng)) do
      _ = Location.upsert_location(profile.id, lat_f, lng_f, true)
      :ok
    else
      _ -> :ok
    end
  end

  defp set_region(params) do
    parts =
      [params["city"], params["district"], params["province"]]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))

    Map.put(params, "region", Enum.join(parts, ", "))
  end

  defp maybe_int(attrs, key) do
    case attrs[key] do
      "" ->
        Map.put(attrs, key, nil)

      nil ->
        attrs

      v when is_binary(v) ->
        case Integer.parse(v) do
          {n, _} -> Map.put(attrs, key, n)
          :error -> Map.put(attrs, key, nil)
        end

      v when is_integer(v) ->
        attrs

      _ ->
        attrs
    end
  end

  defp status_info(nil),
    do: {"⏳ Pending Review", "#D97706", "#FFFBEB", "Your profile will be reviewed by an admin."}

  defp status_info("pending"),
    do:
      {"⏳ Pending Review", "#D97706", "#FFFBEB",
       "Your profile is under admin review. You'll be notified once approved."}

  defp status_info("approved"),
    do: {"✅ Approved", "#065F46", "#F0FDF4", "You are live! Clients can find and book you."}

  defp status_info("rejected"),
    do:
      {"❌ Rejected", "#991B1B", "#FEF2F2",
       "Profile was rejected. Update your details — it will be reviewed again on save."}

  defp status_info("frozen"),
    do:
      {"🚫 Frozen", "#1E40AF", "#EFF6FF",
       "Account frozen by admin. Contact the platform administrator."}

  defp status_info(_),
    do: {"⏳ Pending Review", "#D97706", "#FFFBEB", "Your profile will be reviewed by an admin."}

  defp upload_error_to_string(:too_large), do: "File is too large."
  defp upload_error_to_string(:too_many_files), do: "Too many files selected."
  defp upload_error_to_string(:not_accepted), do: "Unsupported file type."
  defp upload_error_to_string(_), do: "Upload failed."

  defp get_val(form, field) do
    case form do
      %Phoenix.HTML.Form{} ->
        form |> Phoenix.HTML.Form.input_value(field) |> to_string_val()

      _ ->
        ""
    end
  end

  defp to_string_val(nil), do: ""
  defp to_string_val(v), do: to_string(v)

  @impl true
  def render(assigns), do: index(assigns)
end
