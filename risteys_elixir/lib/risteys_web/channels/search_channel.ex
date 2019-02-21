defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel

  def join("search", _message, socket) do
    {:ok, socket}
  end

  def handle_in("query", %{"body" => body}, socket) do
    :ok = push(socket, "result", %{body: body})
    {:noreply, socket}
  end
end
