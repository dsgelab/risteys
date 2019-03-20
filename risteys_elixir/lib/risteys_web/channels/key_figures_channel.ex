defmodule RisteysWeb.KeyFiguresChannel do
  use RisteysWeb, :channel

  def join("key_figures", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("initial_data", %{"body" => path}, socket) do
    code = String.trim_leading(path, "/code/")

    {:ok, results} = Risteys.Data.group_by_sex(code)

    payload = %{
      body: %{
        results: results
      }
    }

    {:reply, {:ok, payload}, socket}
  end

  def handle_in(
        "filter_out",
        %{"body" => %{"path" => path, "filters" => %{"age" => age}}},
        socket
      ) do
    code = String.trim_leading(path, "/code/")

    results =
      case Risteys.Data.group_by_sex(code, age) do
        {:ok, results} ->
          results

        {:error, _} ->
          %{
            all: %{
              nevents: 0,
              mean_age: 0
            },
            male: %{
              nevents: 0,
              mean_age: 0
            },
            female: %{
              nevents: 0,
              mean_age: 0
            }
          }
      end

    payload = %{
      body: %{
        results: results
      }
    }

    {:reply, {:ok, payload}, socket}
  end
end
