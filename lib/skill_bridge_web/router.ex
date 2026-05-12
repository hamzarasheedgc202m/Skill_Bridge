defmodule SkillBridgeWeb.Router do
  use SkillBridgeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SkillBridgeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SkillBridgeWeb.Plugs.Auth
  end

  pipeline :require_auth do
    plug SkillBridgeWeb.Plugs.RequireAuth
  end

  pipeline :user_scope do
    plug SkillBridgeWeb.Plugs.RequireScope, allowed: ["user"]
  end

  pipeline :skilled_scope do
    plug SkillBridgeWeb.Plugs.RequireScope, allowed: ["skilled_person"]
  end

  pipeline :admin_scope do
    plug SkillBridgeWeb.Plugs.RequireScope, allowed: ["admin"]
  end

  pipeline :stripe_webhook do
    plug Plug.Parsers, parsers: [], pass: ["*/*"]
  end

  scope "/webhooks", SkillBridgeWeb do
    pipe_through :stripe_webhook
    post "/stripe", StripeWebhookController, :create
  end

  scope "/", SkillBridgeWeb do
    pipe_through :browser
    live "/", HomeLive, :index
    live "/login", LoginLive, :index
    live "/register", RegisterLive, :index
    live "/admin/login", AdminLoginLive, :index
    live "/browse", PublicBrowseLive, :index
    live "/map", MapLive, :index
    live "/forgot-password", ForgotPasswordLive, :index
    live "/password-reset/:token", ResetPasswordLive, :index
    post "/login", SessionController, :create
    post "/logout", SessionController, :delete
  end

  scope "/", SkillBridgeWeb do
    pipe_through [:browser, :require_auth]
    live "/live-location", MapLive, :index
  end

  # User scope — frozen check applied via on_mount
  scope "/user", SkillBridgeWeb do
    pipe_through [:browser, :require_auth, :user_scope]

    live_session :user,
      on_mount: [{SkillBridgeWeb.Live.Hooks.UserAuth, :ensure_not_frozen}] do
      live "/", UserDashboardLive, :index
      live "/profile", UserProfileLive, :index
      live "/browse", BrowseLive, :index
      live "/browse/:category_id", BrowseCategoryLive, :index
      live "/bookings", UserBookingsLive, :index
      live "/book/:profile_id/confirm", BookLive, :confirm
      live "/book/:profile_id", BookLive, :new
      live "/chat/:booking_id", ChatLive, :index
      live "/pay/:booking_id", PaymentLive, :new
      live "/map", MapLive, :index
    end

    get "/pay/:booking_id/stripe-return", PaymentReturnController, :show
  end

  # Skilled scope — frozen check applied via on_mount
  scope "/skilled", SkillBridgeWeb do
    pipe_through [:browser, :require_auth, :skilled_scope]

    live_session :skilled,
      on_mount: [{SkillBridgeWeb.Live.Hooks.UserAuth, :ensure_not_frozen}] do
      live "/", SkilledDashboardLive, :index
      live "/profile", SkilledProfileLive, :edit
      live "/availability", SkilledAvailabilityLive, :edit
      live "/bookings", SkilledBookingsLive, :index
      live "/chat/:booking_id", ChatLive, :index
      live "/location", SkilledLocationLive, :index
    end
  end

  scope "/admin", SkillBridgeWeb do
    pipe_through [:browser, :require_auth, :admin_scope]

    live_session :admin do
      live "/", AdminDashboardLive, :index
      live "/profiles", AdminProfilesLive, :index
      live "/skilled-persons", AdminSkilledPersonsLive, :index
      live "/bookings", AdminBookingsLive, :index
      live "/chat/:booking_id", ChatLive, :index
      live "/payments", AdminPaymentsLive, :index
      live "/settings", AdminSettingsLive, :index
    end
  end

  if Application.compile_env(:skill_bridge, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SkillBridgeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
