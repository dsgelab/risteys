defmodule RisteysWeb.StatsChannel do
  use RisteysWeb, :channel

  def join("stats", payload, socket) do
    {:ok, socket}
  end


  def handle_in("code", payload, socket) do
    _code = String.trim_leading(payload, "/code/")  # TODO find some reverse of url_for
    data = Risteys.Data.build()
    row_head = [ "" | data.metrics ]
    rows_data =
      for {profile, values} <- Enum.zip(data.profiles, data.table) do
        [ profile | values ]
      end
    response = [ row_head | rows_data ]
    {:reply, {:ok, %{body: response}}, socket}
  end

end
