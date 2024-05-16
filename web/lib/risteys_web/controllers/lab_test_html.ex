defmodule RisteysWeb.LabTestHTML do
  use RisteysWeb, :html

  embed_templates "lab_test_html/*"

  defp prettify_stats(stats, overall_stats) do
    assigns = %{}
    pretty_stats = stats

    sex_female_percent =
      case stats.sex_female_percent do
        nil -> nil
        value -> RisteysWeb.Utils.round_and_str(value, 2) <> "%"
      end

    plot_sex_female_percent = stats.sex_female_percent && plot_sex(stats.sex_female_percent)

    plot_npeople_absolute =
      stats.npeople_total && plot_count(stats.npeople_total, overall_stats.npeople)

    plot_median_n_measurements =
      stats.median_n_measurements &&
        plot_count(stats.median_n_measurements, overall_stats.median_n_measurements)

    plot_median_ndays_first_to_last_measurement =
      stats.median_ndays_first_to_last_measurement && plot_count(stats.median_ndays_first_to_last_measurement, overall_stats.median_ndays_first_to_last_measurement)

    pretty_stats =
      Map.merge(pretty_stats, %{
        sex_female_percent: sex_female_percent,
        plot_npeople_absolute: plot_npeople_absolute,
        plot_sex_female_percent: plot_sex_female_percent,
        plot_median_n_measurements: plot_median_n_measurements,
        plot_median_ndays_first_to_last_measurement: plot_median_ndays_first_to_last_measurement
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

  defp plot_sex(female_percent) do
    assigns = %{female_percent: female_percent}

    ~H"""
    <div style="width: 100%; height: 0.3em; background-color: #bfcde6;">
      <div style={"width: #{@female_percent}%; height: 100%; background-color: #dd9fbd; border-right: 1px solid #777;"}>
      </div>
    </div>
    """
  end

  defp plot_count(npeople, npeople_max) do
    # TODO(Vincent 2024-05-16)
    # Add a `tick` option, that will put a vertical bar (just slightly visible
    # every `tick` %.
    # For example, with `npeople_max = 110` and `tick = 25`, then ticks will
    # show as vertical bars at the following positions: 0, 25, 50, 75, 100.
    assigns = %{
      npeople_percent: 100 * npeople / npeople_max
    }

    ~H"""
    <div style="width: 100%; height: 0.3em; background-color: var(--bg-color-plot-empty)">
      <div style={"width: #{@npeople_percent}%; height: 100%; background-color: var(--bg-color-plot)"}>
      </div>
    </div>
    """
  end
end
