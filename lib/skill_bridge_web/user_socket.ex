defmodule SkillBridgeWeb.UserSocket do
  use Phoenix.Socket

  channel "location:*", SkillBridgeWeb.LocationChannel

  @impl true
  def connect(_params, socket, connect_info) do
    session = connect_info[:session] || %{}

    user_id =
      Map.get(session, :user_id) ||
        Map.get(session, "user_id")

    if is_integer(user_id) do
      {:ok, assign(socket, :user_id, user_id)}
    else
      :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
