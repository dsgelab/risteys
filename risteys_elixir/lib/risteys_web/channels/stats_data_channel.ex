import IO

defmodule RisteysWeb.StatsDataChannel do
  use RisteysWeb, :channel

  alias Risteys.FGEndpoint

  def join("stats_data", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("test_exclusion", %{"endpoint" => endpoint_name}, socket) do
    payload = FGEndpoint.test_exclusion(endpoint_name)

    :ok = push(socket, "result_exclusion", payload)
    {:noreply, socket}

  end

  def handle_in("get_correlations", %{"endpoint" => endpoint_name}, socket) do
    payload = FGEndpoint.list_correlations(endpoint_name)
    :ok = push(socket, "data_correlations", %{rows: payload})
    {:noreply, socket}
  end

  def handle_in("get_cumulative_incidence", %{"endpoint" => endpoint_name, "dataset" => dataset}, socket) do
    payload = FGEndpoint.get_cumulative_incidence_plot_data(endpoint_name, dataset)
    data_cumulative_incidence = "data_cumulative_incidence_" <> dataset
    :ok = push(socket, data_cumulative_incidence, payload)
    {:noreply, socket}
  end

  def handle_in("get_age_histogram", %{"endpoint" => endpoint_name, "dataset" => dataset}, socket) do
    payload =
      FGEndpoint.get_age_histogram(endpoint_name, dataset)
      |> to_d3_shape()

    age_hist_event = "data_age_histogram_" <> dataset
    :ok = push(socket, age_hist_event, %{data: payload})
    {:noreply, socket}
  end

  def handle_in("get_year_histogram", %{"endpoint" => endpoint_name, "dataset" => dataset}, socket) do
    payload =
      FGEndpoint.get_year_histogram(endpoint_name, dataset)
      |> to_d3_shape()

    year_hist_event = "data_year_histogram_" <> dataset
    :ok = push(socket, year_hist_event, %{data: payload})
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

  def handle_in("get_mortality", %{"endpoint" => endpoint_name}, socket) do
    payload = FGEndpoint.get_mortality_data(endpoint_name)
    :ok = push(socket, "data_mortality", %{mortality_data: payload})
    {:noreply, socket}
  end
end
