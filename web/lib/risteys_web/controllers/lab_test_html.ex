defmodule RisteysWeb.LabTestHTML do
  use RisteysWeb, :html

  embed_templates "lab_test_html/*"

  defp index_prettify_stats(stats, overall_stats) do
    assigns = %{}
    pretty_stats = stats

    npeople_total =
      stats.npeople_total && RisteysWeb.Utils.pretty_number(stats.npeople_total)

    sex_female_percent =
      case stats.sex_female_percent do
        nil -> nil
        value -> RisteysWeb.Utils.round_and_str(value, 2) <> "%"
      end

    median_n_measurements =
      stats.median_n_measurements &&
        RisteysWeb.Utils.pretty_number(stats.median_n_measurements, 1)

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
          |> RisteysWeb.Utils.pretty_number(1)
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
        npeople_total: npeople_total,
        sex_female_percent: sex_female_percent,
        median_n_measurements: median_n_measurements,
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
    npeople_both_sex =
      lab_test.npeople_both_sex && RisteysWeb.Utils.pretty_number(lab_test.npeople_both_sex)

    median_n_measurements =
      lab_test.median_n_measurements &&
        RisteysWeb.Utils.pretty_number(lab_test.median_n_measurements, 1)

    median_nmonths_first_to_last_measurement =
      case lab_test.median_ndays_first_to_last_measurement do
        nil ->
          nil

        num ->
          num
          |> days_to_months()
          |> RisteysWeb.Utils.pretty_number(1)
      end

    distributions_lab_values =
      for dist <- lab_test.distributions_lab_values do
        case dist["measurement_unit"] do
          "binary" ->
            prettify_distribution(dist, :binary)

          "titre" ->
            prettify_distribution(dist, :categorical)

          _ ->
            prettify_distribution(dist, :continuous)
        end
      end

    Map.merge(lab_test, %{
      npeople_both_sex: npeople_both_sex,
      median_n_measurements: median_n_measurements,
      median_nmonths_first_to_last_measurement: median_nmonths_first_to_last_measurement,
      distributions_lab_values: distributions_lab_values
    })
  end

  defp prettify_distribution(distribution, :binary) do
    %{
      "bins" => bins,
      "measurement_unit" => measurement_unit
    } = distribution

    bins =
      for %{"bin" => xx, "nrecords" => yy} <- bins, into: %{} do
        xx =
          case xx do
            "0.0" -> :negative
            "1.0" -> :positive
          end

        {xx, yy}
      end

    # Make sure we have display both positive and negative, even if we don't have both of them in the data.
    default = %{
      positive: nil,
      negative: nil
    }

    bins = Map.merge(default, bins)

    bins = [
      %{x: "positive", y: bins.positive},
      %{x: "negative", y: bins.negative}
    ]

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

  defp prettify_distribution(distribution, :categorical) do
    %{
      "bins" => bins,
      "breaks" => _breaks,
      "measurement_unit" => measurement_unit
    } = distribution

    obsplot_bins =
      for %{"bin" => xx, "nrecords" => yy} <- bins do
        xx = RisteysWeb.Utils.parse_number(xx)
        %{x: xx, y: yy}
      end

    assigns = %{
      payload: Jason.encode!(%{bins: obsplot_bins, measurement_unit: measurement_unit})
    }

    obsplot = ~H"""
    <div class="obsplot" data-obsplot-categorical={@payload}></div>
    """

    %{
      measurement_unit: measurement_unit,
      obsplot: obsplot
    }
  end

  defp prettify_distribution(distribution, :continuous) do
    %{"measurement_unit" => measurement_unit} = distribution

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

  def build_obsplot_payload(distribution) do
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
      |> Enum.sort(:asc)

    [break1, break2] = Enum.take(parsed_breaks, 2)
    break_interval = break2 - break1

    # Reconstruct bins by combining break_ranges and parsed_bins from above
    reconstructed_bins =
      reconstruct_bins(bins, parsed_breaks, break_interval)

    %{
      "bins" => reconstructed_bins,
      "measurement_unit" => measurement_unit
    }
  end

  defp reconstruct_bins(bins, breaks, break_interval) do
    bins =
      Enum.map(bins, fn bin ->
        %{
          "bin" => range,
          "nrecords" => nrecords,
          "npeople" => _npeople
        } = bin

        [range_left, range_right] = extract_range_values(range)

        {x1, x1_str, extrema?} =
          case range_left do
            "-inf" ->
              right = RisteysWeb.Utils.parse_number(range_right)
              x1 = right - break_interval
              x1_str = "−∞"
              {x1, x1_str, true}

            _ ->
              x1 = RisteysWeb.Utils.parse_number(range_left)
              x1_str = RisteysWeb.Utils.pretty_number(x1)
              {x1, x1_str, false}
          end

        {x2, x2_str, extrema?} =
          case range_right do
            "inf" ->
              left = RisteysWeb.Utils.parse_number(range_left)
              x2 = left + break_interval
              x2_str = "+∞"
              {x2, x2_str, true}

            _ ->
              x2 = RisteysWeb.Utils.parse_number(range_right)
              x2_str = RisteysWeb.Utils.pretty_number(x2)
              {x2, x2_str, false || extrema?}
          end

        en_dash = "–"
        range_str = x1_str <> en_dash <> x2_str

        %{x1: x1, x2: x2, y: nrecords, range: range_str, extrema?: extrema?}
      end)
      |> Enum.sort_by(fn bin -> bin.x1 end, :asc)

    gaps =
      for [bin_left, bin_right] <- Enum.chunk_every(bins, 2, 1, :discard), reduce: [] do
        acc ->
          if bin_left.x2 != bin_right.x1 do
            [%{left: bin_left.x2, right: bin_right.x1} | acc]
          else
            acc
          end
      end

    first_break = Enum.fetch!(breaks, 0)
    last_break = Enum.fetch!(breaks, -1)
    first_bin = Enum.fetch!(bins, 0)
    last_bin = Enum.fetch!(bins, -1)

    gaps =
      if first_bin.extrema? do
        gaps
      else
        [%{left: first_break, right: first_bin.x1} | gaps]
      end

    gaps =
      if last_bin.extrema? do
        gaps
      else
        last_gap = %{left: last_bin.x2, right: "inf"}
        Enum.concat([gaps, [last_gap]])
      end

    new_bins =
      gaps
      |> Enum.map(&fill_gap(&1, break_interval, last_break))
      |> Enum.concat()

    [bins, new_bins]
    |> Enum.concat()
    |> Enum.map(fn bin ->
      {_, bin} = Map.pop(bin, :extrema?)
      bin
    end)
    |> Enum.sort_by(fn %{x1: x1} -> x1 end, :asc)
  end

  defp fill_gap(gap, break_interval, last_break) do
    gap_right_finite =
      if gap.right == "inf" do
        last_break + break_interval
      else
        gap.right
      end

    n_missing_bins = round((gap_right_finite - gap.left) / break_interval)

    1..n_missing_bins//1
    |> Enum.map(fn ii ->
      right = gap.left + ii * break_interval
      left = right - break_interval

      x1_str = RisteysWeb.Utils.pretty_number(left)

      x2_str =
        if gap.right == "inf" and ii == n_missing_bins do
          "+∞"
        else
          RisteysWeb.Utils.pretty_number(right)
        end

      en_dash = "–"
      range_str = x1_str <> en_dash <> x2_str
      %{x1: left, x2: right, y: 0, range: range_str}
    end)
  end

  defp extract_range_values(range) do
    [x1, x2] = String.split(range, ", ")
    x1 = String.slice(x1, 1..-1//1)
    x2 = String.slice(x2, 0..-2//1)

    [x1, x2]
  end

  defp days_to_months(ndays) do
    # NOTE(Vincent 2024-05-17)
    # Transforming N days to N months, simple way by using a constant as in:
    # https://github.com/ClickHouse/ClickHouse/blob/11e4029c6b080e1ac0b6b47ec919e42e929c9b37/src/Functions/parseTimeDelta.cpp#L28-L30
    days_in_month = 30.5

    ndays / days_in_month
  end
end
