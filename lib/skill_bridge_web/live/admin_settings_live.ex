defmodule SkillBridgeWeb.AdminSettingsLive do
  use SkillBridgeWeb, :live_view
  embed_templates "admin_settings_live_html/*"
  alias SkillBridge.Accounts
  alias SkillBridge.Payments

  @impl true
  def mount(_params, session, socket) do
    user = fetch_user(session)
    setting = Payments.get_platform_setting()

    {:ok,
     socket
     |> assign(:page_title, "Platform Settings")
     |> assign(:current_user, user)
     |> assign(:current_scope, user.role)
     |> assign(:setting, setting)
     |> assign(:fee_type, setting.platform_fee_type)
     |> assign(:fee_value, to_string(setting.platform_fee_value))
     |> assign(:bank_name, setting.bank_name || "")
     |> assign(:bank_account_title, setting.bank_account_title || "")
     |> assign(:bank_account_number, setting.bank_account_number || "")
     |> assign(:jazzcash_number, setting.jazzcash_number || "")
     |> assign(:easypaisa_number, setting.easypaisa_number || "")
     |> assign(:saving, false)}
  end

  defp fetch_user(session) do
    case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end
  end

  @impl true
  def handle_event("set_type", %{"type" => t}, socket),
    do: {:noreply, assign(socket, :fee_type, t)}

  def handle_event("update_payment_field", %{"field" => field, "value" => value}, socket) do
    field_atom = String.to_existing_atom(field)
    {:noreply, assign(socket, field_atom, value)}
  end

  def handle_event("update_value", params, socket) do
    v = Map.get(params, "value", socket.assigns.fee_value)
    {:noreply, assign(socket, :fee_value, v)}
  end

  def handle_event("save", _, socket) do
    val =
      case Integer.parse(socket.assigns.fee_value || "0") do
        {n, _} -> n
        :error -> 0
      end

    case Payments.update_platform_setting(%{
           "platform_fee_type" => socket.assigns.fee_type,
           "platform_fee_value" => val,
           "bank_name" => socket.assigns.bank_name,
           "bank_account_title" => socket.assigns.bank_account_title,
           "bank_account_number" => socket.assigns.bank_account_number,
           "jazzcash_number" => socket.assigns.jazzcash_number,
           "easypaisa_number" => socket.assigns.easypaisa_number
         }) do
      {:ok, setting} ->
        {:noreply,
         socket
         |> assign(:setting, setting)
         |> assign(:saving, false)
         |> put_flash(:info, "Platform settings saved.")}

      {:error, _} ->
        {:noreply,
         socket |> assign(:saving, false) |> put_flash(:error, "Failed to update setting.")}
    end
  end

  @impl true
  def render(assigns), do: index(assigns)
end
