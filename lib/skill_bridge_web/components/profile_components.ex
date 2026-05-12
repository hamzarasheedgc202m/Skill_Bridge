defmodule SkillBridgeWeb.ProfileComponents do
  @moduledoc "Reusable profile UI helpers."
  use Phoenix.Component

  @doc "Renders profile image from a `/uploads/...`, `/images/...`, `https://...`, or legacy `data:` URL."
  attr :src, :string, default: ""
  attr :alt, :string, default: "Profile"
  attr :class, :string, default: "h-20 w-20 rounded-full object-cover border-2 border-slate-200"

  def profile_avatar(assigns) do
    ~H"""
    <%= if @src != "" do %>
      <img src={@src} alt={@alt} class={@class} />
    <% else %>
      <div class={[
        @class,
        "grid place-items-center bg-gradient-to-br from-slate-800 to-teal-600 text-lg font-bold text-white"
      ]}>
        ?
      </div>
    <% end %>
    """
  end
end
