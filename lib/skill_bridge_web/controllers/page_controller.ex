defmodule SkillBridgeWeb.PageController do
  use SkillBridgeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
