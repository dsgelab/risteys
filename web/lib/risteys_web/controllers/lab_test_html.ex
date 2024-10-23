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
          build_obsplot_payload(
            :continuous,
            dist.bins,
            "y",
            "Measured value (#{dist.unit})",
            "Number of records"
          )
      end

    # TODO(Vincent 2024-10-23) ::WIP_DIST_LAB_VALUE
    # distribution_year_of_birth =
    #   build_obsplot_payload(
    #     :years,
    #     lab_test.distribution_year_of_birth["bins"],
    #     :npeople
    #   )

    # distribution_age_first_measurement =
    #   build_obsplot_payload(
    #     :continuous,
    #     lab_test.distribution_age_first_measurement["bins"],
    #     :npeople,
    #     "Age at first measurement",
    #     "Number of people"
    #   )

    # distribution_age_last_measurement =
    #   build_obsplot_payload(
    #     :continuous,
    #     lab_test.distribution_age_last_measurement["bins"],
    #     :npeople,
    #     "Age at last measurement",
    #     "Number of people"
    #   )

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
      distribution_lab_values: distribution_lab_values
      # TODO(Vincent 2024-10-23) ::WIP_DIST_LAB_VALUE
      # distribution_year_of_birth: distribution_year_of_birth,
      # distribution_age_first_measurement: distribution_age_first_measurement,
      # distribution_age_last_measurement: distribution_age_last_measurement,
      # distribution_age_start_of_registry: distribution_age_start_of_registry,
      # distribution_ndays_first_to_last_measurement: distribution_ndays_first_to_last_measurement,
      # distribution_n_measurements_over_years: distribution_n_measurements_over_years,
      # distribution_n_measurements_per_person: distribution_n_measurements_per_person,
      # distribution_value_range_per_person: distribution_value_range_per_person
    })
  end

  defp build_obsplot_payload(:continuous, bins, y_key, x_label, y_label) do
    payload = %{
      "bins" => bins,
      "x_label" => x_label,
      "y_label" => y_label
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

  defp build_obsplot_payload(:years, bins, y_key) do
    bins =
      for bin <- bins do
        %{^y_key => yy} = bin
        x_formatted = to_string(bin.range_left)
        y_formatted = RisteysWeb.Utils.pretty_number(yy)

        %{
          "x1" => bin.range_left_finite,
          "x2" => bin.range_right_finite,
          "y" => yy,
          "x_formatted" => x_formatted,
          "y_formatted" => y_formatted
        }
      end

    payload = %{
      "bins" => bins
    }

    assigns = %{
      payload: Jason.encode!(payload)
    }

    ~H"""
    <div class="obsplot" data-obsplot-type="years" data-obsplot={@payload}></div>
    """
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
end
