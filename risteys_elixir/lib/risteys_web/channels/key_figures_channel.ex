defmodule RisteysWeb.KeyFiguresChannel do
  use RisteysWeb, :channel

  def join("key_figures", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("initial_data", %{"body" => code}, socket) do
    data = Risteys.Data.fake_db(code)

    payload = %{
      body: %{
        results: Risteys.Data.group_by_sex(data)
      }
    }

    {:reply, {:ok, payload}, socket}
  end

  def handle_in(
        "filter_out",
        %{"body" => %{"path" => path, "filters" => %{"age" => age}}},
        socket
      ) do
    # TODO get code from path
    data =
      Risteys.Data.fake_db(path)
      |> Risteys.Data.filter_out(age)

    payload = %{
      body: %{
        results: Risteys.Data.group_by_sex(data)
      }
    }

    {:reply, {:ok, payload}, socket}
  end
end
