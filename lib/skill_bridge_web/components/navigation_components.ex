defmodule SkillBridgeWeb.NavigationComponents do
  @moduledoc "Reusable navigation actions for multi-step screens."
  use Phoenix.Component

  attr :back, :string, default: nil
  attr :next, :string, default: nil
  attr :back_label, :string, default: "Back"
  attr :next_label, :string, default: "Next"
  attr :class, :string, default: ""

  def step_navigation(assigns) do
    ~H"""
    <div class={["mt-6 flex flex-wrap items-center justify-between gap-3", @class]}>
      <.link
        :if={@back}
        navigate={@back}
        class="inline-flex items-center gap-2 rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 shadow-sm transition hover:-translate-y-0.5 hover:border-slate-400 hover:shadow"
      >
        <span class="hero-arrow-left size-4"></span>
        {@back_label}
      </.link>

      <.link
        :if={@next}
        navigate={@next}
        class="ml-auto inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-slate-900 to-slate-700 px-4 py-2.5 text-sm font-semibold text-white shadow transition hover:-translate-y-0.5 hover:shadow-lg"
      >
        {@next_label}
        <span class="hero-arrow-right size-4"></span>
      </.link>
    </div>
    """
  end
end
