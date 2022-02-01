defmodule Risteys.FGEndpoint do
  @moduledoc """
  The FGEndpoint context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.Phenocode
  alias Risteys.Icd10
  alias Risteys.StatsSex
  alias Risteys.Genomics

  alias Risteys.FGEndpoint.Correlation
  alias Risteys.FGEndpoint.ExplainerStep
  alias Risteys.FGEndpoint.StatsCumulativeIncidence

  # -- Phenocode/Endpoint --
  def list_endpoints_ids() do
    Repo.all(from pp in Phenocode, select: {pp.id, pp.name})
    |> Enum.reduce(%{}, fn {id, name}, acc ->
      Map.put_new(acc, name, id)
    end)
  end

  def get_core_endpoints() do
    Repo.all(from pp in Phenocode, where: pp.is_core, select: pp.name)
    |> Enum.into(MapSet.new())
  end

  def find_replacement_endpoints(endpoint) do
    cond do
      endpoint.is_core ->
        {:is_core, nil}

      not is_nil(endpoint.selected_core_id) ->
        {:selected_core, Repo.get!(Phenocode, endpoint.selected_core_id)}

      endpoint.reason_non_core == "exallc_priority" ->
        {:exallc_priority, find_exallc_replacement(endpoint)}

      true ->
        {:correlated, find_correlated_replacements(endpoint)}
    end
  end

  defp find_exallc_replacement(endpoint) do
    map_exallc =
      Repo.all(
        from endp in Phenocode,
          where: like(endp.name, "%_EXALLC"),
          select: {endp.name, endp}
      )
      |> Enum.into(%{})

    exallc_alternative = endpoint.name <> "_EXALLC"

    Map.get(map_exallc, exallc_alternative)
  end

  defp find_correlated_replacements(endpoint) do
    overlap_threshold = 0.5
    max_results = 3

    list_correlated =
      Repo.all(
        from corr in Correlation,
          join: endp in Phenocode,
          on: corr.phenocode_b_id == endp.id,
          where:
            corr.phenocode_a_id == ^endpoint.id and
              corr.phenocode_b_id != ^endpoint.id and
              corr.case_overlap >= ^overlap_threshold and
              endp.is_core,
          select: %{name: endp.name},
          order_by: [desc: corr.case_overlap],
          limit: ^max_results
      )

    case list_correlated do
      [] -> nil
      _ -> list_correlated
    end
  end

  # -- Endpoint Explainer --
  def get_explainer_steps(endpoint) do
    steps = [
      %{
        name: :all,
        data: nil
      },
      %{
        name: :sex_rule,
        data: endpoint.sex
      },
      %{
        name: :conditions,
        data: parse_conditions(endpoint)
      },
      %{
        name: :filter_registries,
        data: parse_registry_filters(endpoint)
      },
      %{
        name: :multi,
        data: parse_multi(endpoint)
      },
      %{
        name: :min_number_events,
        data: parse_min_number_events(endpoint)
      },
      %{
        name: :includes,
        data: parse_include(endpoint)
      }
    ]

    counts = get_explainer_step_counts(endpoint)

    Enum.map(steps, fn step ->
      %{name: step_name} = step
      # nil or count as an integer
      count = counts[step_name]
      Map.put_new(step, :nindivs_post_step, count)
    end)
  end

  defp parse_conditions(endpoint) do
    parse_logic_expression(endpoint.conditions)
  end

  defp parse_control_conditions(endpoint) do
    parse_logic_expression(endpoint.control_conditions)
  end

  defp parse_logic_expression(nil), do: []

  defp parse_logic_expression(expr) do
    non_word = ~r{\W}

    Regex.split(non_word, expr, include_captures: true, trim: true)
    |> Enum.reduce([""], fn token, acc ->
      [previous | remaining] = acc
      item = previous <> token
      acc = [item | remaining]

      if Regex.match?(non_word, token) do
        acc
      else
        ["" | acc]
      end
    end)
    # we assume the last token is an endpoint name
    |> Enum.drop(1)
    # reversing to get original order since we prepended items
    |> Enum.reverse()
  end

  defp parse_registry_filters(endpoint) do
    # Order will be discarded since it will be used as Map keys
    registries = [
      :outpat_icd,
      :outpat_icd_exp,
      :hd_icd_10_atc,
      :hd_icd_10,
      :hd_icd_10_exp,
      :hd_icd_9,
      :hd_icd_8,
      :hd_icd_10_excl,
      :hd_icd_9_excl,
      :hd_icd_8_excl,
      :cod_icd_10,
      :cod_icd_10_exp,
      :cod_icd_9,
      :cod_icd_8,
      :cod_icd_10_excl,
      :cod_icd_10_excl_exp,
      :cod_icd_9_excl,
      :cod_icd_8_excl,
      :oper_nom,
      :oper_hl,
      :oper_hp1,
      :oper_hp2,
      :kela_reimb,
      :kela_reimb_icd,
      :kela_reimb_icd_exp,
      :kela_atc,
      :kela_vnro,
      :canc_topo,
      :canc_topo_excl,
      :canc_morph,
      :canc_morph_excl,
      :canc_behav
    ]

    icd10s_exp = list_expanded_icd10s(endpoint)

    endpoint
    |> Map.take(registries)
    |> Map.merge(icd10s_exp)
    |> Enum.reject(fn {_registry, values} ->
      # for data coming from the database when ICD expansion lead to empty list
      is_nil(values) or
        values == []
    end)
    |> Enum.into(%{})
  end

  defp list_expanded_icd10s(endpoint) do
    # Return list of Icd10 if the rule was expanded in import step, otherwise an empty list.
    expanded =
      Repo.all(
        from assoc in Risteys.PhenocodeIcd10,
          join: endpoint in Phenocode,
          on: assoc.phenocode_id == endpoint.id,
          join: icd10 in Icd10,
          on: assoc.icd10_id == icd10.id,
          where: assoc.phenocode_id == ^endpoint.id,
          select: %{registry: assoc.registry, icd10: icd10}
      )
      |> Enum.group_by(
        fn %{registry: registry} -> registry end,
        fn %{icd10: icd10} -> icd10 end
      )
      |> Enum.map(fn {registry, icd10s} ->
        case registry do
          "COD" -> {:cod_icd_10_exp, icd10s}
          "COD_EXCL" -> {:cod_icd_10_excl_exp, icd10s}
          "HD" -> {:hd_icd_10_exp, icd10s}
          "HD_EXCL" -> {:hd_icd_10_excl_exp, icd10s}
          "KELA" -> {:kela_reimb_icd_exp, icd10s}
          "OUTPAT" -> {:outpat_icd_exp, icd10s}
        end
      end)
      |> Map.new()

    defaults = %{
      cod_icd_10_exp: [],
      cod_icd_10_excl_exp: [],
      hd_icd_10_exp: [],
      hd_icd_10_excl_exp: [],
      kela_reimb_icd_exp: [],
      outpat_icd_exp: []
    }

    Map.merge(defaults, expanded)
  end

  defp parse_multi(endpoint) do
    multi = %{}
    mode = parse_mode(endpoint)
    only_icdver = parse_icdver(endpoint)

    multi =
      case endpoint.pre_conditions do
        nil ->
          multi

        _ ->
          Map.put(multi, :precond, endpoint.pre_conditions)
      end

    multi =
      case parse_main_only(endpoint) do
        false -> multi
        main_only -> Map.put(multi, :main_only, main_only)
      end

    multi =
      if Enum.empty?(mode) do
        multi
      else
        Map.put(multi, :mode, mode)
      end

    if Enum.empty?(only_icdver) do
      multi
    else
      Map.put(multi, :only_icdver, only_icdver)
    end
  end

  defp parse_main_only(endpoint) do
    not is_nil(endpoint.hd_mainonly) or not is_nil(endpoint.cod_mainonly)
  end

  defp parse_mode(endpoint) do
    endpoint
    |> Map.take([:hd_icd_8, :hd_icd_9, :hd_icd_10, :cod_icd_8, :cod_icd_9, :cod_icd_10])
    |> Map.values()
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn rule -> String.starts_with?(rule, "%") end)
    # remove duplicates, e.g. same in HD and COD
    |> MapSet.new()
  end

  defp parse_icdver(endpoint) do
    endpoint
    |> Map.take([:hd_icd_8, :hd_icd_9, :hd_icd_10, :cod_icd_8, :cod_icd_9, :cod_icd_10])
    |> Enum.reject(fn {_registry, rule} -> is_nil(rule) end)
    |> Enum.map(fn {registry, _rule} -> registry end)
    |> Enum.map(fn reg_ver ->
      case reg_ver do
        :hd_icd_8 -> {:hd, 8}
        :hd_icd_9 -> {:hd, 9}
        :hd_icd_10 -> {:hd, 10}
        :cod_icd_8 -> {:cod, 8}
        :cod_icd_9 -> {:cod, 9}
        :cod_icd_10 -> {:cod, 10}
      end
    end)
    |> Enum.group_by(
      fn {registry, _icd_version} -> registry end,
      fn {_registry, icd_version} -> icd_version end
    )
  end

  defp parse_min_number_events(endpoint) do
    drug_purch_lookup = not is_nil(endpoint.kela_atc) or not is_nil(endpoint.kela_vnro)

    case {drug_purch_lookup, endpoint.kela_atc_needother} do
      # the min. number of events rule only applies to drug purchases
      {false, _} -> nil
      # defaults at least 3 drug purchases
      {true, nil} -> 3
      {true, "SINGLE_OK"} -> 1
      # need at least 3 purchases AND other rules
      {true, "YES"} -> :and_need_other_rule
      # undefined, passing on the information
      {true, value} -> value
    end
  end

  defp parse_include(endpoint) do
    parse_delim_endpoints(endpoint.include)
  end

  defp parse_control_exclude(endpoint) do
    parse_delim_endpoints(endpoint.control_exclude)
  end

  defp parse_delim_endpoints(nil), do: []

  defp parse_delim_endpoints(endpoints) do
    String.split(endpoints, "|")
  end

  def upsert_explainer_step(attrs) do
    case Repo.get_by(ExplainerStep, phenocode_id: attrs.phenocode_id, step: attrs.step) do
      nil -> %ExplainerStep{}
      existing -> existing
    end
    |> ExplainerStep.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp get_explainer_step_counts(endpoint) do
    Repo.all(
      from ee in ExplainerStep,
        where: ee.phenocode_id == ^endpoint.id,
        select: %{step: ee.step, nindivs: ee.nindivs}
    )
    |> Enum.reduce(%{}, fn %{nindivs: count, step: step_name}, acc ->
      step_name = String.to_atom(step_name)
      Map.put_new(acc, step_name, count)
    end)
  end

  # -- Control definitions --
  def get_control_definitions(endpoint) do
    [
      %{
        field: :control_exclude,
        value: parse_control_exclude(endpoint)
      },
      %{
        field: :control_preconditions,
        value: endpoint.control_preconditions
      },
      %{
        field: :control_conditions,
        value: parse_control_conditions(endpoint)
      }
    ]
    |> Enum.reject(fn %{value: val} -> is_nil(val) or val == [] end)
  end

  # -- Histograms --
  defp get_histograms(endpoint_name) do
    endpoint = Repo.get_by!(Phenocode, name: endpoint_name)
    sex_all = 0

    %{
      distrib_age: %{"hist" => hist_age},
      distrib_year: %{"hist" => hist_year}
    } =
      Repo.one(
        from ss in StatsSex,
          where:
            ss.phenocode_id == ^endpoint.id and
              ss.sex == ^sex_all
      )

    %{age: hist_age, year: hist_year}
  end

  def get_age_histogram(endpoint_name) do
    %{age: hist} = get_histograms(endpoint_name)
    hist
  end

  def get_year_histogram(endpoint_name) do
    %{year: hist} = get_histograms(endpoint_name)
    hist
  end

  # -- Correlation --
  def upsert_correlation(attrs) do
    case Repo.get_by(Correlation,
           phenocode_a_id: attrs.phenocode_a_id,
           phenocode_b_id: attrs.phenocode_b_id
         ) do
      nil -> %Correlation{}
      existing -> existing
    end
    |> Correlation.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def list_correlations(phenocode_name) do
    phenocode = Repo.get_by!(Phenocode, name: phenocode_name)

    Repo.all(
      from corr in Correlation,
        join: pp in Phenocode,
        on: corr.phenocode_b_id == pp.id,
        where:
          corr.phenocode_a_id == ^phenocode.id and
            corr.phenocode_a_id != corr.phenocode_b_id,
        select: %{
          name: pp.name,
          longname: pp.longname,
          case_overlap: corr.case_overlap,
          gws_hits: pp.gws_hits,
          coloc_gws_hits_same_dir: corr.coloc_gws_hits_same_dir,
          coloc_gws_hits_opp_dir: corr.coloc_gws_hits_opp_dir
        }
    )
    |> Enum.map(fn row ->
      coloc_gws_hits =
        case {row.coloc_gws_hits_same_dir, row.coloc_gws_hits_opp_dir} do
          {nil, nil} ->
            nil

          {nil, hits} ->
            hits

          {hits, nil} ->
            hits

          {hits_same_dir, hits_opp_dir} ->
            hits_same_dir + hits_opp_dir
        end

      Map.put_new(row, :coloc_gws_hits, coloc_gws_hits)
    end)
  end

  def broader_endpoints(phenocode, limit \\ 5) do
    Repo.all(
      from corr in Correlation,
        join: pp in Phenocode,
        on: corr.phenocode_b_id == pp.id,
        where:
          corr.phenocode_a_id == ^phenocode.id and
            corr.phenocode_a_id != corr.phenocode_b_id and
            corr.shared_of_a == 1.0,
        order_by: [desc: corr.shared_of_b],
        limit: ^limit,
        select: pp
    )
  end

  def narrower_endpoints(phenocode, limit \\ 5) do
    Repo.all(
      from corr in Correlation,
        join: pp in Phenocode,
        on: corr.phenocode_b_id == pp.id,
        where:
          corr.phenocode_a_id == ^phenocode.id and
            corr.phenocode_a_id != corr.phenocode_b_id and
            corr.shared_of_b == 1.0,
        order_by: [desc: corr.shared_of_a],
        limit: ^limit,
        select: pp
    )
  end

  def list_variants_by_correlation(phenocode) do
    by_corr =
      Repo.all(
        from corr in Correlation,
          join: pp in Phenocode,
          on: corr.phenocode_b_id == pp.id,
          where: corr.phenocode_a_id == ^phenocode.id,
          select: %{
            corr_endpoint: pp.name,
            variants_same_dir: corr.variants_same_dir,
            variants_opp_dir: corr.variants_opp_dir,
            beta_same_dir: corr.rel_beta_same_dir,
            beta_opp_dir: corr.rel_beta_opp_dir
          }
      )
      # Remove correlations without any variants
      |> Enum.reject(fn corr ->
        Enum.empty?(corr.variants_same_dir) and Enum.empty?(corr.variants_opp_dir)
      end)

    # Gather all the variants
    all_corr_variants =
      for corr <- by_corr, reduce: MapSet.new() do
        acc ->
          variants =
            MapSet.union(MapSet.new(corr.variants_same_dir), MapSet.new(corr.variants_opp_dir))

          MapSet.union(acc, variants)
      end

    # Map each variant to its closest genes
    genes =
      for variant <- all_corr_variants, reduce: %{} do
        acc ->
          Map.put_new(acc, variant, Genomics.list_closest_genes(variant))
      end

    # Merge all info into one data structure
    for corr <- by_corr do
      variants_same_dir = Enum.map(corr.variants_same_dir, fn vv -> {vv, genes[vv]} end)
      variants_opp_dir = Enum.map(corr.variants_opp_dir, fn vv -> {vv, genes[vv]} end)
      %{corr | variants_same_dir: variants_same_dir, variants_opp_dir: variants_opp_dir}
    end
  end

  # -- StatsCumulativeIncidence --
  def create_cumulative_incidence(attrs) do
    %StatsCumulativeIncidence{}
    |> StatsCumulativeIncidence.changeset(attrs)
    |> Repo.insert()
  end

  def delete_cumulative_incidence(endpoint_ids) do
    Repo.delete_all(
      from cumul_inc in StatsCumulativeIncidence,
        where: cumul_inc.phenocode_id in ^endpoint_ids
    )
  end

  def get_cumulative_incidence_plot_data(endpoint_name) do
    %{id: endpoint_id} = Repo.get_by(Phenocode, name: endpoint_name)

    # Values will be converted from [0, 1] to [0, 100]
    females = get_cumulinc_sex(endpoint_id, "female")
    males = get_cumulinc_sex(endpoint_id, "male")

    %{
      females: females,
      males: males
    }
  end

  defp get_cumulinc_sex(endpoint_id, sex) do
    Repo.all(
      from stats in StatsCumulativeIncidence,
        where:
          stats.phenocode_id == ^endpoint_id and
            stats.sex == ^sex,
        # The following will be reversed when we build the list by prepending values
        order_by: [desc: stats.age]
    )
    |> Enum.reduce([], fn changeset, acc ->
      %{
        age: age,
        value: value
      } = changeset

      # convert value to percentage
      data_point = %{age: age, value: value * 100}
      [data_point | acc]
    end)
  end
end
