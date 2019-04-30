defmodule RisteysWeb.KeyFiguresChannelTest do
  use RisteysWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      socket(RisteysWeb.UserSocket, "user_id", %{some: :assign})
      |> subscribe_and_join(RisteysWeb.KeyFiguresChannel, "key_figures")

    Risteys.DataCase.data_fixture("XYZ00", 20)

    {:ok, socket: socket}
  end

  test "push initial data", %{socket: socket} do
    ref = push(socket, "initial_data", %{"body" => "XYZ00"})

    assert_reply ref, :ok, %{
      body: %{
        results: %{
          all: %{
            nevents: _,
            prevalence: _,
            mean_age: _,
            case_fatality: _,
            rehosp: _
          },
          male: %{
            nevents: _,
            prevalence: _,
            mean_age: _,
            case_fatality: _,
            rehosp: _
          },
          female: %{
            nevents: _,
            prevalence: _,
            mean_age: _,
            case_fatality: _,
            rehosp: _
          }
        }
      }
    }
  end

  test "push new data after receiving a 'filter_out'", %{socket: socket} do
    req_payload = %{
      "body" => %{
        "path" => "/code/XYZ00",
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
            mean_age: _,
            case_fatality: _,
            rehosp: _
          },
          male: %{
            nevents: _,
            mean_age: _,
            case_fatality: _,
            rehosp: _
          },
          female: %{
            nevents: _,
            mean_age: _,
            case_fatality: _,
            rehosp: _
          }
        }
      }
    }
  end
end
