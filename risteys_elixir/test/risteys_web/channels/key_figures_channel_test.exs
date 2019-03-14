defmodule RisteysWeb.KeyFiguresChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.KeyFiguresChannel, "key_figures")

    {:ok, socket: socket}
  end

  test "push initial data", %{socket: socket} do
    ref = push(socket, "initial_data", %{"body" => "J11"})

    assert_reply ref, :ok, %{
      body: %{
        results: %{
          all: %{
            nevents: _,
            mean_age: _
          },
          male: %{
            nevents: _,
            mean_age: _
          },
          female: %{
            nevents: _,
            mean_age: _
          }
        }
      }
    }
  end

  test "push new data after receiving a 'filter_out'", %{socket: socket} do
    req_payload = %{
      "body" => %{
        "path" => "/code/X00",
        "filters" => %{
          "age" => [40, 50]
        }
      }
    }

    ref = push(socket, "filter_out", req_payload)

    assert_reply ref, :ok, %{
      body: %{
        results: %{
          all: %{
            nevents: _,
            mean_age: _
          },
          female: %{
            nevents: _,
            mean_age: _
          },
          male: %{
            nevents: _,
            mean_age: _
          }
        }
      }
    }
  end
end
