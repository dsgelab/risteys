defmodule RisteysWeb.LabTestHTML do
  use RisteysWeb, :html

  embed_templates "lab_test_html/*"

  defp index_prettify_stats(stats, overall_stats) do
    assigns = %{}
    pretty_stats = stats

    sex_female_percent =
      case stats.sex_female_percent do
        nil -> nil
        value -> RisteysWeb.Utils.round_and_str(value, 2) <> "%"
      end

    plot_sex_female_percent = plot_sex(stats.sex_female_percent)

    plot_npeople_absolute = plot_count(stats.npeople_total, overall_stats.npeople)

    plot_median_n_measurements =
      plot_count(stats.median_n_measurements, overall_stats.median_n_measurements)

    median_nmonths_first_to_last_measurement =
      case stats.median_ndays_first_to_last_measurement do
        nil ->
          nil

        _ ->
          stats.median_ndays_first_to_last_measurement
          |> days_to_months()
          |> RisteysWeb.Utils.round_and_str(1)
      end

    tick_every_year = 365.25

    plot_median_duration_first_to_last_measurement =
      plot_count(
        stats.median_ndays_first_to_last_measurement,
        overall_stats.median_ndays_first_to_last_measurement,
        tick_every_year
      )

    pretty_stats =
      Map.merge(pretty_stats, %{
        sex_female_percent: sex_female_percent,
        plot_npeople_absolute: plot_npeople_absolute,
        plot_sex_female_percent: plot_sex_female_percent,
        plot_median_n_measurements: plot_median_n_measurements,
        median_nmonths_first_to_last_measurement: median_nmonths_first_to_last_measurement,
        plot_median_duration_first_to_last_measurement:
          plot_median_duration_first_to_last_measurement
      })

    missing_value = ~H"""
    <span class="missing-value">&mdash;</span>
    """

    pretty_stats =
      for {key, value} <- pretty_stats, into: %{} do
        {key, value || missing_value}
      end

    pretty_stats
  end

  defp plot_sex(nil), do: ""

  defp plot_sex(female_percent) do
    assigns = %{female_percent: female_percent}

    ~H"""
    <div style="width: 100%; height: 0.3em; background-color: #bfcde6;">
      <div style={"width: #{@female_percent}%; height: 100%; background-color: #dd9fbd; border-right: 1px solid #777;"}>
      </div>
    </div>
    """
  end

  defp plot_count(npeople, npeople_max, tick_every \\ nil)

  defp plot_count(nil, _, _), do: ""

  defp plot_count(npeople, npeople_max, tick_every) do
    tick_percents =
      case tick_every do
        nil ->
          []

        _ ->
          last = round(npeople_max)
          step = round(tick_every)
          Range.to_list(step..last//step)
      end
      |> Enum.map(&(100 * &1 / npeople_max))

    assigns = %{
      npeople_percent: 100 * npeople / npeople_max,
      tick_percents: tick_percents
    }

    ~H"""
    <div style="width: 100%; height: 0.3em; background-color: var(--bg-color-plot-empty); position: relative;">
      <div style={"width: #{@npeople_percent}%; height: 100%; background-color: var(--bg-color-plot); position: absolute;"}>
      </div>
      <%= for tick_percent <- @tick_percents do %>
        <div style={"width: #{tick_percent}%; height: 100%; border-right: 1px solid var(--bg-color-plot-empty); position: absolute;"}>
        </div>
      <% end %>
    </div>
    """
  end

  def show_prettify_stats(lab_test) do
    median_nmonths_first_to_last_measurement =
      case lab_test.median_ndays_first_to_last_measurement do
        nil ->
          nil

        _ ->
          lab_test.median_ndays_first_to_last_measurement
          |> days_to_months()
          |> RisteysWeb.Utils.round_and_str(1)
      end

    distributions_lab_values =
      for dist <- lab_test.distributions_lab_values do
        case dist["measurement_unit"] do
          "binary" -> prettify_distribution(:binary, dist)
          _ -> prettify_distribution(:continuous, dist)
        end
      end

    lab_test
    |> Map.put(
      :median_nmonths_first_to_last_measurement,
      median_nmonths_first_to_last_measurement
    )
    |> Map.put(:distributions_lab_values, distributions_lab_values)
  end

  defp prettify_distribution(:binary, distribution) do
    %{
      "bins" => bins,
      "measurement_unit" => measurement_unit
    } = distribution

    bins =
      for %{"bin" => xx, "nrecords" => yy} <- bins do
        xx =
          case xx do
            "0.0" ->
              "negative"

            "1.0" ->
              "positive"
          end

        %{x: xx, y: yy}
      end

    assigns = %{
      payload: Jason.encode!(%{bins: bins})
    }

    obsplot = ~H"""
    <div class="obsplot" data-obsplot-discrete={@payload}></div>
    """

    %{
      measurement_unit: measurement_unit,
      obsplot: obsplot
    }
  end

  defp prettify_distribution(
         :continuous,
         %{"measurement_unit" => measurement_unit} = distribution
       ) do
    payload =
      distribution
      |> build_obsplot_payload()
      |> Jason.encode!()

    assigns = %{
      payload: payload
    }

    obsplot = ~H"""
    <div class="obsplot" data-obsplot-continuous={@payload}></div>
    """

    %{measurement_unit: measurement_unit, obsplot: obsplot}
  end

  defp build_obsplot_payload(distribution) do
    %{
      "bins" => bins,
      "breaks" => breaks,
      "measurement_unit" => measurement_unit
    } = distribution

    # Derive break interval
    # TODO(Vincent 2024-05-27)  Use pre-computed break interval value from the
    # data when that's implemented and available in DB.
    parsed_breaks =
      breaks
      |> Enum.map(&RisteysWeb.Utils.parse_number/1)
      |> Enum.sort()

    [break1, break2] = Enum.take(parsed_breaks, 2)
    break_interval = break2 - break1

    # Collect bins and breaks
    map_nrecords =
      for bin <- bins, into: %{} do
        %{
          "bin" => range,
          "npeople" => _npeople,
          "nrecords" => nrecords
        } = bin

        [left, _right] = extract_range_values(range)

        {left, nrecords}
      end

    breaks = Enum.sort_by(breaks, &RisteysWeb.Utils.parse_number/1, :asc)
    breaks = Enum.concat([["-inf"], breaks, ["+inf"]])
    bin_ranges = Enum.chunk_every(breaks, 2, 1)

    obsplot_bins =
      for [left, right] <- bin_ranges do
        x1 =
          case left do
            "-inf" -> RisteysWeb.Utils.parse_number(right) - break_interval
            num -> RisteysWeb.Utils.parse_number(num)
          end

        x2 =
          case right do
            "+inf" -> x1 + break_interval
            num -> RisteysWeb.Utils.parse_number(num)
          end

        # If a bin is missing, it's either because there is no record in it, or
        # because it was discarded due to N<5.
        # In both cases, we want to set y=0
        default_y = 0
        yy = Map.get(map_nrecords, left, default_y)

        # TODO(Vincent 2024-05-27)  Use new pretty_number instead of round_and_str
        x1_str =
          case left do
            "-inf" -> "−∞"
            _ -> left |> RisteysWeb.Utils.parse_number() |> RisteysWeb.Utils.round_and_str(2)
          end

        x2_str =
          case right do
            "+inf" -> "+∞"
            _ -> right |> RisteysWeb.Utils.parse_number() |> RisteysWeb.Utils.round_and_str(2)
          end

        en_dash = "–"
        range_str = "#{x1_str}#{en_dash}#{x2_str}"

        %{x1: x1, x2: x2, y: yy, range: range_str}
      end
      |> maybe_remove_negative_range()
      # Remove bins without any values from the RIGHT tail.
      |> Enum.reverse()
      |> Enum.drop_while(fn %{y: yy} -> yy == 0 end)
      |> Enum.reverse()

    max =
      obsplot_bins
      |> Enum.map(fn %{x2: x2} -> x2 end)
      |> Enum.max()

    min =
      obsplot_bins
      |> Enum.map(fn %{x1: x1} -> x1 end)
      |> Enum.min()
      |> min(0)

    %{
      "bins" => obsplot_bins,
      "measurement_unit" => measurement_unit,
      "domain" => [min, max]
    }
  end

  defp extract_range_values(range) do
    [x1, x2] = String.split(range, ", ")
    x1 = String.slice(x1, 1..-1//1)
    x2 = String.slice(x2, 0..-2//1)

    [x1, x2]
  end

  # Remove the first bin if both x<0 and y==0
  defp maybe_remove_negative_range(bins) do
    [first | rest] = bins

    if first.x1 < 0 and first.y == 0 do
      rest
    else
      bins
    end
  end

  defp days_to_months(ndays) do
    # NOTE(Vincent 2024-05-17)
    # Transforming N days to N months, simple way by using a constant as in:
    # https://github.com/ClickHouse/ClickHouse/blob/11e4029c6b080e1ac0b6b47ec919e42e929c9b37/src/Functions/parseTimeDelta.cpp#L28-L30
    days_in_month = 30.5

    ndays / days_in_month
  end
end
