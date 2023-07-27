defmodule RisteysWeb.Live.InteractiveMortality do
  use RisteysWeb, :live_view

  def mount(_params, _session, socket) do
    default_age = 50
    selected_age = default_age
    socket =
      socket
      |> assign(:form, to_form(%{"age" => default_age}))
      |> assign(:selected_age, selected_age)

    {:ok, socket, layout: false}
  end

  def handle_event("update_age", %{"age" => age}, socket) do
    socket = assign(socket, :selected_age, String.to_integer(age))
    {:noreply, socket}
  end

  defp show_risk(nyear, age, sex) do
    # Deal with missing data
    case compute_risk(nyear, age, sex) do
      nil -> "no data"
      risk -> risk
    end
  end

  # TODO: move compute functions to lib/ near the Mortality module
  defp compute_risk(nyear, age, sex) do
    # TODO: use real data and proper formula
    nyear + age
  end
end
