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

  attr :avg, :any, default: nil
  attr :count, :integer, default: 0
  attr :class, :string, default: "text-xs text-base-content/70"

  def star_rating(assigns) do
    ~H"""
    <%= if @count > 0 and @avg do %>
      <p class={@class}>
        <span class="text-amber-500 font-semibold">★ {@avg}</span>
        <span class="text-base-content/50">
          ({@count} {if @count == 1, do: "review", else: "reviews"})
        </span>
      </p>
    <% else %>
      <p class={@class}>No reviews yet</p>
    <% end %>
    """
  end
end
