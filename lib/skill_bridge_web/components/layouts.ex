defmodule SkillBridgeWeb.Layouts do
  use SkillBridgeWeb, :html
  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :any, default: nil
  attr :current_user, :any, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%!-- Root wrapper: flex row so sidebar + content sit side by side on desktop --%>
    <div class="min-h-screen bg-base-200 flex font-sans">
      <%!-- ============================================================
           MOBILE TOP BAR (hamburger + logo) — hidden on lg+
      ============================================================ --%>
      <header class="lg:hidden fixed top-0 left-0 right-0 z-40 flex items-center gap-3 px-4 h-14 bg-base-100 border-b border-base-300 shadow-sm">
        <button
          id="sidebar-open-btn"
          aria-label="Open navigation menu"
          aria-expanded="false"
          aria-controls="app-sidebar"
          phx-click={JS.dispatch("sb:open", to: "#app-sidebar")}
          class="flex items-center justify-center w-9 h-9 rounded-lg text-base-content hover:bg-base-200 transition-colors focus:outline-none focus:ring-2 focus:ring-primary"
        >
          <.icon name="hero-bars-3" class="w-5 h-5" />
        </button>
        <a href={dashboard_path(@current_scope)} class="flex items-center gap-2 text-base-content no-underline">
          <span class="w-2.5 h-2.5 rounded-full bg-teal-500 shrink-0"></span>
          <span class="font-bold text-lg tracking-tight font-serif">SkillBridge</span>
        </a>
        <%!-- Right-side quick actions on mobile --%>
        <div class="ml-auto flex items-center gap-2">
          <.theme_toggle />
          <%= if @current_user do %>
            <span class="text-xs text-base-content/60 max-w-[100px] truncate hidden sm:block">
              {@current_user.name}
            </span>
          <% end %>
        </div>
      </header>

      <%!-- ============================================================
           MOBILE OVERLAY BACKDROP
      ============================================================ --%>
      <div
        id="sidebar-overlay"
        phx-click={JS.dispatch("sb:close", to: "#app-sidebar")}
        class="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm hidden lg:hidden transition-opacity duration-300"
        aria-hidden="true"
      >
      </div>

      <%!-- ============================================================
           SIDEBAR — fixed left, full height
           Desktop: always visible, w-64
           Mobile: slides in over content as overlay
      ============================================================ --%>
      <aside
        id="app-sidebar"
        phx-hook=".SidebarToggle"
        aria-label="Main navigation"
        class={[
          "fixed inset-y-0 left-0 z-50 w-64 flex flex-col",
          "bg-base-100 border-r border-base-300 shadow-xl",
          "transition-transform duration-300 ease-in-out",
          "-translate-x-full lg:translate-x-0"
        ]}
      >
        <%!-- Sidebar header: Logo + close button (mobile) --%>
        <div class="flex items-center justify-between px-5 py-4 border-b border-base-300 shrink-0">
          <a
            href={dashboard_path(@current_scope)}
            class="flex items-center gap-2 text-base-content no-underline hover:opacity-80 transition-opacity"
          >
            <span class="w-2.5 h-2.5 rounded-full bg-teal-500 shrink-0"></span>
            <span class="font-bold text-xl tracking-tight font-serif">SkillBridge</span>
          </a>
          <button
            id="sidebar-close-btn"
            aria-label="Close navigation menu"
            phx-click={JS.dispatch("sb:close", to: "#app-sidebar")}
            class="lg:hidden flex items-center justify-center w-8 h-8 rounded-lg text-base-content/60 hover:bg-base-200 hover:text-base-content transition-colors focus:outline-none focus:ring-2 focus:ring-primary"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <%!-- Navigation links — scrollable --%>
        <nav class="flex-1 overflow-y-auto px-3 py-4 space-y-1" aria-label="Sidebar navigation">
          <%!-- Public links --%>
          <.sidebar_section_label>General</.sidebar_section_label>
          <.sidebar_link href="/" icon="hero-home">Home</.sidebar_link>
          <.sidebar_link href="/browse" icon="hero-magnifying-glass">Browse</.sidebar_link>
          <.sidebar_link href="/map" icon="hero-map">Map</.sidebar_link>

          <%!-- User links --%>
          <%= if @current_scope == "user" do %>
            <div class="my-3 border-t border-base-300"></div>
            <.sidebar_section_label>My Account</.sidebar_section_label>
            <.sidebar_link href="/user" icon="hero-squares-2x2">Dashboard</.sidebar_link>
            <.sidebar_link href="/user/profile" icon="hero-user-circle">Profile</.sidebar_link>
            <.sidebar_link href="/user/browse" icon="hero-briefcase">Find Pros</.sidebar_link>
            <.sidebar_link href="/user/bookings" icon="hero-calendar-days">Bookings</.sidebar_link>
          <% end %>

          <%!-- Skilled Person links --%>
          <%= if @current_scope == "skilled_person" do %>
            <div class="my-3 border-t border-base-300"></div>
            <.sidebar_section_label>Professional</.sidebar_section_label>
            <.sidebar_link href="/skilled" icon="hero-squares-2x2">Dashboard</.sidebar_link>
            <.sidebar_link href="/skilled/profile" icon="hero-user-circle">My Profile</.sidebar_link>
            <.sidebar_link href="/skilled/availability" icon="hero-clock">Schedule</.sidebar_link>
            <.sidebar_link href="/skilled/bookings" icon="hero-calendar-days">Bookings</.sidebar_link>
            <.sidebar_link href="/skilled/location" icon="hero-map-pin">Location</.sidebar_link>
          <% end %>

          <%!-- Admin links --%>
          <%= if @current_scope == "admin" do %>
            <div class="my-3 border-t border-base-300"></div>
            <.sidebar_section_label color="warning">Admin Panel</.sidebar_section_label>
            <.sidebar_link href="/admin" icon="hero-shield-check" accent="warning">
              Admin Home
            </.sidebar_link>
            <.sidebar_link href="/admin/profiles" icon="hero-users">Profiles</.sidebar_link>
            <.sidebar_link href="/admin/skilled-persons" icon="hero-briefcase">
              Professionals
            </.sidebar_link>
            <.sidebar_link href="/admin/bookings" icon="hero-calendar-days">Bookings</.sidebar_link>
            <.sidebar_link href="/admin/payments" icon="hero-banknotes">Payments</.sidebar_link>
            <.sidebar_link href="/admin/settings" icon="hero-cog-6-tooth">Settings</.sidebar_link>
          <% end %>
        </nav>

        <%!-- Sidebar footer: theme toggle + user info + logout --%>
        <div class="shrink-0 border-t border-base-300 px-4 py-4 space-y-3">
          <%!-- Theme toggle row --%>
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
              Theme
            </span>
            <.theme_toggle />
          </div>

          <%!-- User info + logout --%>
          <%= if @current_user do %>
            <div class="flex items-center gap-3 rounded-xl bg-base-200 px-3 py-2.5">
              <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center shrink-0">
                <.icon name="hero-user" class="w-4 h-4 text-primary" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-base-content truncate">{@current_user.name}</p>
                <p class="text-xs text-base-content/50 truncate">{@current_user.email}</p>
              </div>
            </div>
            <form action="/logout" method="post" class="w-full">
              <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
              <button
                type="submit"
                class="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-sm font-medium text-error hover:bg-error/10 transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-error group"
                aria-label="Sign out"
              >
                <.icon
                  name="hero-arrow-right-on-rectangle"
                  class="w-4 h-4 group-hover:translate-x-0.5 transition-transform"
                /> Sign out
              </button>
            </form>
          <% else %>
            <div class="flex flex-col gap-2">
              <a
                href="/login"
                class="w-full flex items-center justify-center gap-2 px-4 py-2 rounded-xl text-sm font-medium border border-base-300 text-base-content hover:bg-base-200 transition-colors duration-200 no-underline focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> Sign in
              </a>
              <a
                href="/register"
                class="w-full flex items-center justify-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold bg-primary text-primary-content hover:opacity-90 transition-opacity duration-200 no-underline focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <.icon name="hero-user-plus" class="w-4 h-4" /> Register
              </a>
            </div>
          <% end %>
        </div>

        <%!-- Colocated JS hook — manages open/close via custom events + active link highlighting --%>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".SidebarToggle">
          export default {
            mounted() {
              const sidebar = this.el;
              const overlay = document.getElementById("sidebar-overlay");
              const openBtn  = document.getElementById("sidebar-open-btn");

              const open = () => {
                sidebar.classList.remove("-translate-x-full");
                overlay.classList.remove("hidden");
                if (openBtn) openBtn.setAttribute("aria-expanded", "true");
                document.body.classList.add("overflow-hidden");
              };

              const close = () => {
                sidebar.classList.add("-translate-x-full");
                overlay.classList.add("hidden");
                if (openBtn) openBtn.setAttribute("aria-expanded", "false");
                document.body.classList.remove("overflow-hidden");
              };

              // Highlight the active nav link based on current URL
              const highlightActive = () => {
                const path = window.location.pathname;
                sidebar.querySelectorAll(".sidebar-nav-link").forEach(link => {
                  const href = link.getAttribute("data-sidebar-href") || link.getAttribute("href");
                  // Exact match for "/" to avoid highlighting everything
                  const isActive = href === "/"
                    ? path === "/"
                    : path === href || path.startsWith(href + "/");
                  if (isActive) {
                    link.classList.add("bg-primary/10", "text-primary", "font-semibold");
                    link.classList.remove("text-base-content/70", "text-warning");
                    link.setAttribute("aria-current", "page");
                  } else {
                    link.classList.remove("bg-primary/10", "text-primary", "font-semibold");
                    link.setAttribute("aria-current", "false");
                  }
                });
              };

              sidebar.addEventListener("sb:open",  open);
              sidebar.addEventListener("sb:close", close);

              // Close on Escape key
              document.addEventListener("keydown", (e) => {
                if (e.key === "Escape" && !sidebar.classList.contains("-translate-x-full")) {
                  close();
                }
              });

              // Close sidebar on LiveView navigation (mobile) and re-highlight
              window.addEventListener("phx:page-loading-stop", () => {
                if (window.innerWidth < 1024) close();
                highlightActive();
              });

              // Initial highlight on mount
              highlightActive();
            }
          }
        </script>
      </aside>

      <%!-- ============================================================
           MAIN CONTENT AREA
           On desktop: offset by sidebar width (ml-64)
           On mobile:  full width (no offset), top-padded for mobile header
      ============================================================ --%>
      <div class="flex-1 flex flex-col min-w-0 lg:ml-64 pt-14 lg:pt-0">
        <%!-- Flash messages --%>
        <.flash_group flash={@flash} />

        <%!-- Page content --%>
        <main class="flex-1 w-full max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8 py-6 pb-12">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # Sidebar helpers
  # ----------------------------------------------------------------

  attr :color, :string, default: nil
  slot :inner_block, required: true

  def sidebar_section_label(assigns) do
    ~H"""
    <p class={[
      "px-3 mb-1 mt-2 text-xs font-semibold uppercase tracking-widest select-none",
      if(@color == "warning", do: "text-warning", else: "text-base-content/40")
    ]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :accent, :string, default: nil
  slot :inner_block, required: true

  def sidebar_link(assigns) do
    ~H"""
    <a
      href={@href}
      data-sidebar-href={@href}
      class={[
        "sidebar-nav-link flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-medium",
        "transition-all duration-200 no-underline group",
        "hover:bg-base-200 hover:translate-x-0.5",
        "focus:outline-none focus:ring-2 focus:ring-primary",
        if(@accent == "warning",
          do: "text-warning hover:bg-warning/10",
          else: "text-base-content/70 hover:text-base-content"
        )
      ]}
    >
      <.icon
        name={@icon}
        class={[
          "w-5 h-5 shrink-0 transition-transform duration-200 group-hover:scale-110",
          if(@accent == "warning",
            do: "text-warning",
            else: "text-base-content/50 group-hover:text-primary"
          )
        ]}
      />
      <span class="truncate">{render_slot(@inner_block)}</span>
    </a>
    """
  end

  # ----------------------------------------------------------------
  # nav_link — kept for backward compat (renders as sidebar_link style)
  # ----------------------------------------------------------------

  attr :href, :string, required: true
  attr :color, :string, default: nil
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center px-3 py-2 rounded-xl text-sm font-medium no-underline",
        "transition-all duration-200 hover:bg-base-200",
        "focus:outline-none focus:ring-2 focus:ring-primary"
      ]}
      style={if @color, do: "color: #{@color}", else: ""}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  # ----------------------------------------------------------------
  # Flash group
  # ----------------------------------------------------------------

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="fixed top-16 lg:top-4 right-4 z-[200] flex flex-col gap-2 max-w-sm w-full pointer-events-none"
    >
      <div class="pointer-events-auto">
        <.flash kind={:info} flash={@flash} />
      </div>
      <div class="pointer-events-auto">
        <.flash kind={:error} flash={@flash} />
      </div>
      <div class="pointer-events-auto">
        <.flash
          id="client-error"
          kind={:error}
          title="Connection lost"
          phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
          phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
          hidden
        >
          Reconnecting… <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
        </.flash>
      </div>
      <div class="pointer-events-auto">
        <.flash
          id="server-error"
          kind={:error}
          title="Something went wrong!"
          phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
          phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
          hidden
        >
          Reconnecting… <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
        </.flash>
      </div>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # Admin wrapper layout
  # ----------------------------------------------------------------

  attr :flash, :map, required: true
  attr :current_scope, :any, default: nil
  attr :current_user, :any, default: nil
  attr :page_title, :string, default: "Admin"
  slot :inner_block, required: true

  def app_admin(assigns) do
    ~H"""
    <.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="mb-5 flex items-center gap-2 rounded-xl border border-warning/30 bg-warning/5 px-4 py-3 text-xs font-medium text-warning">
        <.icon name="hero-shield-check" class="w-4 h-4 shrink-0" />
        Restricted admin area · All actions logged
      </div>
      {render_slot(@inner_block)}
    </.app>
    """
  end

  # ----------------------------------------------------------------
  # Theme toggle (3-way: system / light / dark)
  # ----------------------------------------------------------------

  def theme_toggle(assigns) do
    ~H"""
    <div
      class="relative flex flex-row items-center border border-base-300 bg-base-200 rounded-full p-0.5 gap-0.5"
      aria-label="Select theme"
      role="group"
    >
      <button
        class="flex p-1.5 rounded-full cursor-pointer hover:bg-base-100 transition-colors focus:outline-none focus:ring-2 focus:ring-primary"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
        aria-label="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-3.5 opacity-70 hover:opacity-100" />
      </button>
      <button
        class="flex p-1.5 rounded-full cursor-pointer hover:bg-base-100 transition-colors focus:outline-none focus:ring-2 focus:ring-primary"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
        aria-label="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-3.5 opacity-70 hover:opacity-100" />
      </button>
      <button
        class="flex p-1.5 rounded-full cursor-pointer hover:bg-base-100 transition-colors focus:outline-none focus:ring-2 focus:ring-primary"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
        aria-label="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-3.5 opacity-70 hover:opacity-100" />
      </button>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # Role-based dashboard path helper
  # ----------------------------------------------------------------

  defp dashboard_path("admin"), do: "/admin"
  defp dashboard_path("user"), do: "/user"
  defp dashboard_path("skilled_person"), do: "/skilled"
  defp dashboard_path(_), do: "/"
end
