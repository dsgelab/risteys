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
end
