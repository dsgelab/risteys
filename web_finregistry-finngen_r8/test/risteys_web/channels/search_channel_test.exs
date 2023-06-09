defmodule RisteysWeb.SearchChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.SearchChannel, "search")

    Risteys.DataCase.data_fixture("XYZ00")

    {:ok, socket: socket}
  end

  test "search for a endpoint by longname", %{socket: socket} do
    push(socket, "query", %{"body" => "XYZ00"})

    assert_push "results", %{
      body: %{
        results: [
          [
            "Endpoint long name",
            [
              %{
                content: _,
                endpoint: _,
                url: _
              }
            ]
          ],
	  [
	    "Endpoint name",
	    [
	      %{
		content: _,
		endpoint: _,
		url: _,
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
