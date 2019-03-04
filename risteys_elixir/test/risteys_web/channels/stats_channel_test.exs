defmodule RisteysWeb.StatsChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.StatsChannel, "stats")

    {:ok, socket: socket}
  end

  test "handle getting code data", %{socket: socket} do
    ref = push(socket, "code", "J10_BRONCH")

    payload = %{
      body: %{
        data: [
          ["", "C3_CANCER", "E4_DMNAS", "I9_K_CARDIAC"],
          ["diagnosed w/ J10_BRONCH", 28, 23, 27],
          ["whole population", 54, 45, 49],
          ["User defined sub-pop 1", 54, 45, 49]
        ],
        pop_filter: Risteys.Popfilter.default_filters()
      }
    }

    assert_reply ref, :ok, ^payload
  end
end
