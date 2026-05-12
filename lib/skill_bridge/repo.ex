defmodule SkillBridge.Repo do
  use Ecto.Repo,
    otp_app: :skill_bridge,
    adapter: Ecto.Adapters.Postgres
end
