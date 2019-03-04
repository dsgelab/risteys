defmodule RisteysWeb.StatsChannel do
  use RisteysWeb, :channel

  def join("stats", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("code", payload, socket) do
    # TODO find some reverse of url_for
    code = String.trim_leading(payload, "/code/")

    # Table data
    data = Risteys.Data.build(code)
    row_head = ["" | data.metrics]

    rows_data =
      for {profile, values} <- Enum.zip(data.profiles, data.table) do
        [profile | values]
      end

    table_data = [row_head | rows_data]

    # Filters
    pop_filter = Risteys.Popfilter.default_filters()

    # Payload
    response = %{
      data: table_data,
      pop_filter: pop_filter
    }

    {:reply, {:ok, %{body: response}}, socket}
  end
end
