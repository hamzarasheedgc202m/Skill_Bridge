defmodule SkillBridge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Ensure the uploads directory exists at startup (dev + prod)
    uploads_dir = Application.app_dir(:skill_bridge, "priv/static/uploads/profiles")
    File.mkdir_p!(uploads_dir)

    children = [
      SkillBridgeWeb.Telemetry,
      SkillBridge.Repo,
      {DNSCluster, query: Application.get_env(:skill_bridge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SkillBridge.PubSub},
      # Start a worker by calling: SkillBridge.Worker.start_link(arg)
      # {SkillBridge.Worker, arg},
      # Start to serve requests, typically the last entry
      SkillBridgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SkillBridge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SkillBridgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
