defmodule RisteysWeb.SearchChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.SearchChannel, "search")

    Risteys.DataCase.data_fixture("XYZ00")

    {:ok, socket: socket}
  end

  test "search for a phenocode by longname", %{socket: socket} do
    push(socket, "query", %{"body" => "XYZ00"})

    assert_push "results", %{
      body: %{
        results: [
          [
            "Phenocode long name",
            [
              %{
                content: _,
                phenocode: _,
                url: _
              }
            ]
          ],
	  [
	    "Phenocode name",
	    [
	      %{
		content: _,
		phenocode: _,
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
