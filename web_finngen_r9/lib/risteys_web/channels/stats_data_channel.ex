defmodule RisteysWeb.StatsDataChannel do
  use RisteysWeb, :channel

  alias Risteys.FGEndpoint

  def join("stats_data", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("get_correlations", %{"endpoint" => endpoint_name}, socket) do
    payload = FGEndpoint.list_correlations(endpoint_name)
    :ok = push(socket, "data_correlations", %{rows: payload})
    {:noreply, socket}
  end

  def handle_in("get_cumulative_incidence", %{"endpoint" => endpoint_name}, socket) do
    payload = FGEndpoint.get_cumulative_incidence_plot_data(endpoint_name)
    :ok = push(socket, "data_cumulative_incidence", payload)
    {:noreply, socket}
  end

  def handle_in("get_age_histogram", %{"endpoint" => endpoint_name}, socket) do
    payload =
      endpoint_name
      |> FGEndpoint.get_age_histogram()
      |> to_d3_shape()

    :ok = push(socket, "data_age_histogram", %{data: payload})
    {:noreply, socket}
  end

  def handle_in("get_year_histogram", %{"endpoint" => endpoint_name}, socket) do
    payload =
      endpoint_name
      |> FGEndpoint.get_year_histogram()
      |> to_d3_shape()

    :ok = push(socket, "data_year_histogram", %{data: payload})
    {:noreply, socket}
  end

  defp to_d3_shape(histogram) do
    Enum.map(histogram, fn [[left, right], count] ->
      %{"interval" => %{
	   "left" => left,
	   "right" => right
	 },
	"count" => count
       }
    end)
  end
end
