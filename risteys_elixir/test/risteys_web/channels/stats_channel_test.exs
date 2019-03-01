defmodule RisteysWeb.StatsChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.StatsChannel, "stats")

    {:ok, socket: socket}
  end

  test "handle getting code data", %{socket: socket} do
    ref = push(socket, "code", "J10")

    payload = %{
      body: %{
        data: [
          ["", "asthma", "cancer", "diabetes", "death"],
          ["diagnosed w/", 22, 28, 24, 21],
          ["whole population", 53, 53, 48, 50],
          ["User defined sub-pop 1", 53, 53, 48, 50]
        ],
        pop_filter: Risteys.Popfilter.default_filters()
      }
    }

    assert_reply ref, :ok, ^payload
  end
end
