defmodule RisteysWeb.SearchChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.SearchChannel, "search")

    {:ok, socket: socket}
  end

  test "search for a phenocode", %{socket: socket} do
    push(socket, "query", %{"body" => "L12_OTHERCONTACT"})

    payload = %{
      body: %{
        results: [
          %{
            description: "Other contact dermatitis",
            phenocode: "<span class=\"highlight\">L12_OTHERCONTACT</span>",
            url: "/code/L12_OTHERCONTACT"
          }
        ]
      }
    }

    assert_push "results", ^payload
  end

  test "search with empty string", %{socket: socket} do
    push(socket, "query", %{"body" => ""})
    assert_push "results", %{body: %{results: []}}
  end
end
