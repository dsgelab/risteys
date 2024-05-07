defmodule RisteysWeb.LabTestHTML do
  use RisteysWeb, :html

  embed_templates "lab_test_html/*"

  defp prettify_stats(stats, loinc_component_stats, overall_stats) do
    assigns = %{}
    pretty_stats = stats

    # There might be no stats for a LOINC component. If that's the case, the we
    # transform the nil to an empty map, facilitating downstream processing.
    loinc_component_stats = loinc_component_stats || %{}

    sex_female_percent =
      case stats.sex_female_percent do
        nil -> nil
        value -> RisteysWeb.Utils.round_and_str(value, 2)
      end

    plot_sex_female_percent = stats.sex_female_percent && plot_sex(stats.sex_female_percent)

    plot_npeople_absolute =
      stats.npeople_total && plot_npeople(stats.npeople_total, overall_stats.npeople)

    plot_npeople_relative =
      stats.npeople_total && plot_npeople(stats.npeople_total, loinc_component_stats.npeople)

    pretty_stats =
      Map.merge(pretty_stats, %{
        sex_female_percent: sex_female_percent,
        plot_npeople_absolute: plot_npeople_absolute,
        plot_npeople_relative: plot_npeople_relative,
        plot_sex_female_percent: plot_sex_female_percent
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
      <div style={"width: #{@female_percent}%; height: 100%; background-color: #e0c3d0; border-right: 1px solid #777;"}>
      </div>
    </div>
    """
  end

  defp plot_npeople(npeople, npeople_max) do
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
