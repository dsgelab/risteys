defmodule RisteysWeb.PlotDataChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.PlotDataChannel, "plot_data")

    {:ok, socket: socket}
  end

  test "get_cumulative_incidence replies with status ok", %{socket: socket} do
    ref = push socket, "get_cumulative_incidence", %{"endpoint" => "TEST_ENDPOINT"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  # test "shout broadcasts to plot_data:lobby", %{socket: socket} do
  #   push socket, "shout", %{"hello" => "all"}
  #   assert_broadcast "shout", %{"hello" => "all"}
  # end

  # test "broadcasts are pushed to the client", %{socket: socket} do
  #   broadcast_from! socket, "broadcast", %{"some" => "data"}
  #   assert_push "broadcast", %{"some" => "data"}
  # end
end
