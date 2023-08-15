defmodule RisteysWeb.Live.InteractiveMortality do
  use RisteysWeb, :live_view

  def mount(_params, %{"endpoint_name" => endpoint_name, "mortality_data" => mortality_data}, socket) do
    default_age = 50
    selected_age = default_age

    socket =
      socket
      |> assign(:form, to_form(%{"age" => default_age}))
      |> assign(:selected_age, selected_age)
      |> assign(:endpoint_name, endpoint_name)
      |> assign(:mortality_data, mortality_data)

    {:ok, socket, layout: false}
  end

  def handle_event("update_age", %{"age" => age}, socket) do
    socket = assign(socket, :selected_age, String.to_integer(age))
    {:noreply, socket}
  end

  defp show_risk(data, nyear, age, sex) do
    # Deal with missing data
    if data |> Map.fetch!(sex) |> Map.fetch!(:bch) do
      compute_risk(data, nyear, age, sex)
    else
      "No data"
    end
  end

  # TODO: move compute functions to lib/ near the Mortality module
  defp compute_risk(data, n_year, age, sex) do
    comp1 = compute_S(data, age, age + n_year, sex)
    comp2 = compute_S(data, age, age, sex)
    ar =
      if is_nil(comp1) or is_nil(comp2) do
        nil
      else
        (1 - comp1 / comp2) * 100
     end

    cond do
      is_nil(ar) ->
        "No data"

      ar < 0.001 ->
        "< 0.001%"

      ar > 95 ->
        "> 95%"

      true ->
        ar = ar |> Float.round(3) |> Float.to_string()
        ar <> "%"
    end
  end

  defp compute_S(data, age, t_time, sex) do
    birth_year = 2022 - age
    birth_year_coef = data |> Map.fetch!(sex) |> Map.fetch!(:birth_year) |> Map.fetch!(:coef)
    birth_year_mean = data |> Map.fetch!(sex) |> Map.fetch!(:birth_year) |> Map.fetch!(:mean)

    exposure_coef = data |> Map.fetch!(sex) |> Map.fetch!(:exposure) |> Map.fetch!(:coef)
    exposure_mean = data |> Map.fetch!(sex) |> Map.fetch!(:exposure) |> Map.fetch!(:mean)

    bch = get_bch(data, t_time, sex)

    if is_nil(bch) or is_nil(birth_year_coef) or is_nil(birth_year_mean) or is_nil(exposure_coef) or is_nil(exposure_mean) do
      nil
    else
      :math.exp(-bch * :math.exp(
        birth_year_coef * (birth_year - birth_year_mean) +
        exposure_coef * (1 - exposure_mean)
      ))
    end
  end

  defp get_bch(data, age, sex) do
    data
    |> Map.fetch!(sex)
    |> Map.fetch!(:bch)
    |> Map.get(age / 1)  # Elixir trick to conver an integer to a float
  end
end
