defmodule RisteysWeb.SearchChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.SearchChannel, "search")

    Risteys.DataCase.data_fixture("XYZ00", 20)

    {:ok, socket: socket}
  end

  test "search for a phenocode", %{socket: socket} do
    push(socket, "query", %{"body" => "XYZ00"})

    assert_push "results", %{
      body: %{
        results: [
          [
            "Phenocode code",
            [
              %{
                content: _,
                phenocode: _,
                url: _
              }
            ]
          ]
        ]
      }
    }
  end

  test "search with empty string", %{socket: socket} do
    push(socket, "query", %{"body" => ""})
    assert_push "results", %{body: %{results: []}}
  end
end
