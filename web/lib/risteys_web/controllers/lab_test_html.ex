defmodule RisteysWeb.LabTestHTML do
  use RisteysWeb, :html

  embed_templates "lab_test_html/*"

  defp index_prettify_stats(stats, overall_stats) do
    assigns = %{}
    pretty_stats = stats

    npeople_total =
      stats.npeople_total && RisteysWeb.Utils.pretty_number(stats.npeople_total)

    plot_npeople_absolute = plot_count(stats.npeople_total, overall_stats.npeople)

    percent_people_two_plus_records =
      stats.percent_people_two_plus_records &&
        RisteysWeb.Utils.pretty_number(stats.percent_people_two_plus_records) <> "%"

    plot_percent_people_two_plus_records =
      plot_count(
        stats.percent_people_two_plus_records,
        overall_stats.percent_people_two_plus_records
      )

    sex_female_percent =
      case stats.sex_female_percent do
        nil -> nil
        value -> RisteysWeb.Utils.round_and_str(value, 2) <> "%"
      end

    plot_sex_female_percent = plot_sex(stats.sex_female_percent)

    median_years_first_to_last_measurement =
      case stats.median_years_first_to_last_measurement do
        nil ->
          nil

        _ ->
          stats.median_years_first_to_last_measurement
          |> RisteysWeb.Utils.pretty_number(2)
      end

    # in years
    tick_every = 1.0

    plot_median_duration_first_to_last_measurement =
      plot_count(
        stats.median_years_first_to_last_measurement,
        overall_stats.median_years_first_to_last_measurement,
        tick_every
      )

    pretty_stats =
      Map.merge(pretty_stats, %{
        npeople_total: npeople_total,
        plot_npeople_absolute: plot_npeople_absolute,
        sex_female_percent: sex_female_percent,
        plot_sex_female_percent: plot_sex_female_percent,
        percent_people_two_plus_records: percent_people_two_plus_records,
        plot_percent_people_two_plus_records: plot_percent_people_two_plus_records,
        median_years_first_to_last_measurement: median_years_first_to_last_measurement,
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
      <div style={"width: #{@female_percent}%; height: 100%; background-color: #dd9fbd; border-right: 1px solid #000;"}>
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

    percent_people_two_plus_records =
      lab_test.percent_people_two_plus_records &&
        RisteysWeb.Utils.pretty_number(lab_test.percent_people_two_plus_records)

    median_n_measurements =
      lab_test.median_n_measurements &&
        RisteysWeb.Utils.pretty_number(lab_test.median_n_measurements, 1)

    median_years_first_to_last_measurement =
      case lab_test.median_years_first_to_last_measurement do
        nil ->
          nil

        num ->
          num
          |> RisteysWeb.Utils.pretty_number(2)
      end

    distribution_lab_values =
      case lab_test.distribution_lab_values do
        nil ->
          nil

        dist ->
          # TODO(Vincent 2024-10-30) ::OBSPLOT_FORMATTING
          # Ideally the formatting would be already correct when it comes here.
          # So either make it correct in the pipeline output, or otherwise when
          # importing the data.
          bins =
            for bin <- dist.bins do
              %{bin | "x1x2_formatted" => "#{bin["x1x2_formatted"]} #{dist.unit}"}
            end

          dist = %{dist | bins: bins}

          build_obsplot_payload(
            :continuous,
            dist,
            "y",
            "Measured value",
            "Number of records"
          )
      end

    qc_table =
      Enum.map(lab_test.qc_table, fn qc_row ->
        percent_missing_formatted =
          qc_row.percent_missing_measurement_value &&
            RisteysWeb.Utils.pretty_number(qc_row.percent_missing_measurement_value)

        plot_test_outcome =
          build_obsplot_payload(:qc_table_test_outcome, qc_row.test_outcome_counts)

        plot_harmonized_value_distribution =
          qc_row.distribution_measurement_values &&
            build_obsplot_payload(
              :qc_table_harmonized_value_distribution,
              qc_row.distribution_measurement_values
            )

        %{
          percent_missing_measurement_value_formatted: percent_missing_formatted,
          plot_harmonized_value_distribution: plot_harmonized_value_distribution,
          plot_test_outcome: plot_test_outcome
        }
        |> Map.merge(qc_row)
      end)

    distribution_year_of_birth =
      if is_nil(lab_test.distribution_year_of_birth) do
        nil
      else
        build_obsplot_payload(:years, lab_test.distribution_year_of_birth)
      end

    distribution_age_first_measurement =
      case lab_test.distribution_age_first_measurement do
        nil ->
          nil

        dist ->
          # TODO(Vincent 2024-10-30) ::OBSPLOT_FORMATTING
          bins =
            for bin <- dist["bins"] do
              %{bin | "x1x2_formatted" => "#{bin["x1x2_formatted"]} years"}
            end

          dist = %{dist | "bins" => bins}

          build_obsplot_payload(
            :continuous,
            dist,
            :y,
            "Age at first measurement",
            "Number of people"
          )
      end

    distribution_age_last_measurement =
      case lab_test.distribution_age_last_measurement do
        nil ->
          nil

        dist ->
          build_obsplot_payload(
            :continuous,
            dist,
            :y,
            "Age at last measurement",
            "Number of people"
          )
      end

    #   build_obsplot_payload(
    #     :continuous,
    #     lab_test.distribution_age_last_measurement["bins"],
    #     :npeople,
    #     "Age at last measurement",
    #     "Number of people"
    #   )

    # TODO(Vincent 2024-10-23) ::WIP_DIST_LAB_VALUE
    # distribution_age_start_of_registry =
    #   build_obsplot_payload(
    #     :continuous,
    #     lab_test.distribution_age_start_of_registry["bins"],
    #     :npeople,
    #     "Age at start of registry",
    #     "Number of people"
    #   )

    # distribution_ndays_first_to_last_measurement =
    #   build_obsplot_payload(
    #     :continuous,
    #     lab_test.distribution_ndays_first_to_last_measurement["bins"],
    #     :npeople,
    #     "Duration from first to last measurement (days)",
    #     "Number of people"
    #   )

    # distribution_n_measurements_over_years =
    #   build_obsplot_payload(:year_months, lab_test.distribution_n_measurements_over_years)

    # distribution_n_measurements_per_person =
    #   build_obsplot_payload(
    #     :n_measurements_per_person,
    #     lab_test.distribution_n_measurements_per_person
    #   )

    # distribution_value_range_per_person =
    #   build_obsplot_payload(
    #     :continuous,
    #     lab_test.distribution_value_range_per_person["bins"],
    #     :npeople,
    #     "Value range (max − min) per person for the most common measurement unit.",
    #     "Number of people"
    #   )

    Map.merge(lab_test, %{
      npeople_both_sex: npeople_both_sex,
      percent_people_two_plus_records: percent_people_two_plus_records,
      median_n_measurements: median_n_measurements,
      median_years_first_to_last_measurement: median_years_first_to_last_measurement,
      distribution_lab_values: distribution_lab_values,
      qc_table: qc_table,
      distribution_year_of_birth: distribution_year_of_birth,
      distribution_age_first_measurement: distribution_age_first_measurement,
      distribution_age_last_measurement: distribution_age_last_measurement
      # TODO(Vincent 2024-10-23) ::WIP_DIST_LAB_VALUE
      # distribution_age_start_of_registry: distribution_age_start_of_registry,
      # distribution_ndays_first_to_last_measurement: distribution_ndays_first_to_last_measurement,
      # distribution_n_measurements_over_years: distribution_n_measurements_over_years,
      # distribution_n_measurements_per_person: distribution_n_measurements_per_person,
      # distribution_value_range_per_person: distribution_value_range_per_person
    })
  end

  defp build_obsplot_payload(:continuous, distribution, y_key, x_label, y_label) do
    # TODO(Vincent 2024-10-30) Refactor distribution schemas so that they arrive here with a
    # unified structure.
    # Currently dist lab values has :bins, :break_min, etc. has schema fields, so they it arrives
    # here :bins, etc. But the other distributions have schemas with just :distribution, so they
    # arrive here with "bins", etc. has keys.
    # I think the best way would be that all the distribution schemas have :bins, :xmin, :xmax,
    # etc. has keys.
    bins =
      case distribution do
        %{bins: bins} -> bins
        %{"bins" => bins} -> bins
      end

    xmin =
      case distribution do
        %{break_min: xmin} -> xmin
        %{"xmin" => xmin} -> xmin
      end

    xmax =
      case distribution do
        %{break_max: xmax} -> xmax
        %{"xmax" => xmax} -> xmax
      end

    payload = %{
      bins: bins,
      x_label: x_label,
      y_label: y_label,
      xmin: xmin,
      xmax: xmax
    }

    assigns = %{
      payload: Jason.encode!(payload)
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="continuous" data-obsplot={@payload}></div>
    """
  end

  defp build_obsplot_payload(:binary, bins, y_key, x_label, y_label) do
    bins =
      for bin <- bins, into: %{} do
        %{^y_key => yy, "range" => xx} = bin

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
      payload: Jason.encode!(%{"bins" => bins, "x_label" => x_label, "y_label" => y_label})
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="discrete" data-obsplot={@payload}></div>
    """
  end

  defp build_obsplot_payload(:categorical, bins, y_key, x_label, y_label) do
    bins =
      for %{"range" => xx, ^y_key => yy} <- bins do
        xx = RisteysWeb.Utils.parse_number(xx)
        %{"x" => xx, "y" => yy}
      end

    payload = %{
      "bins" => bins,
      "x_label" => x_label,
      "y_label" => y_label
    }

    assigns = %{
      payload: Jason.encode!(payload)
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="categorical" data-obsplot={@payload}></div>
    """
  end

  defp build_obsplot_payload(:years, distribution) do
    %{
      "bins" => list_bins,
      "break_min" => break_min,
      "break_max" => break_max
    } = distribution

    # Remove (-inf; _] and (_ ; +inf)
    bins = Enum.reject(list_bins, fn %{"x1" => x1, "x2" => x2} -> is_nil(x1) or is_nil(x2) end)

    assigns = %{
      payload: Jason.encode!(%{xmin: break_min, xmax: break_max, bins: bins})
    }

    if Enum.empty?(bins) do
      nil
    else
      ~H"""
      <div class="obsplot" data-obsplot-type="years" data-obsplot={@payload}></div>
      """
    end
  end

  defp build_obsplot_payload(:year_months, bins) do
    payload = %{
      "bins" => bins
    }

    assigns = %{
      payload: Jason.encode!(payload)
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="year-months" data-obsplot={@payload}></div>
    """
  end

  defp build_obsplot_payload(:n_measurements_per_person, bins) do
    payload = %{
      "bins" => bins
    }

    assigns = %{
      payload: Jason.encode!(payload)
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="n-measurements-per-person" data-obsplot={@payload}></div>
    """
  end

  defp build_obsplot_payload(:qc_table_test_outcome, nil) do
    "Distribution not available"
  end

  defp build_obsplot_payload(:qc_table_test_outcome, distribution) do
    sum_count =
      distribution
      |> Enum.map(fn %{"count" => count} -> count end)
      |> Enum.sum()

    bins =
      for bin <- distribution do
        %{"count" => count, "test_outcome" => test_outcome} = bin

        percent_count = 100 * count / sum_count
        x_label = RisteysWeb.Utils.pretty_number(percent_count) <> "%"

        yy = test_outcome || "NA"

        %{x: percent_count, y: yy, x_label: x_label}
      end

    order_labels = [
      "NA",
      "N",
      "A",
      "AA",
      "L",
      "LL",
      "H",
      "HH"
    ]

    bins =
      for label <- order_labels do
        with_this_label = Enum.filter(bins, fn %{y: yy} -> yy == label end)

        case with_this_label do
          [] -> nil
          # There should be only one bin with a given label
          [head | _rest] -> head
        end
      end
      |> Enum.reject(&is_nil/1)

    assigns = %{
      payload: Jason.encode!(%{bins: bins})
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="qc-table-test-outcome" data-obsplot={@payload}></div>
    """
  end

  defp build_obsplot_payload(:qc_table_harmonized_value_distribution, distribution) do
    %{
      "bins" => list_bins,
      "break_min" => break_min,
      "break_max" => break_max,
      "measurement_unit" => measurement_unit
    } = distribution

    bins =
      for bin <- list_bins do
        %{"x1" => x1, "x2" => x2, "yy" => yy, "x1x2_formatted" => x1x2_formatted} = bin

        %{
          x1: x1,
          x2: x2,
          y: yy,
          x1x2_formatted: x1x2_formatted <> "  " <> measurement_unit
        }
      end
      # Remove (-inf; _] and (_ ; +inf)
      |> Enum.reject(fn bin -> is_nil(bin.x1) or is_nil(bin.x2) end)

    assigns = %{
      payload:
        Jason.encode!(%{
          xmin: break_min,
          xmax: break_max,
          measurement_unit: measurement_unit,
          bins: bins
        })
    }

    if Enum.empty?(bins) do
      nil
    else
      ~H"""
      <div
        class="obsplot"
        data-obsplot-type="qc-table-harmonized-value-distribution"
        data-obsplot={@payload}
      >
      </div>
      """
    end
  end
end
