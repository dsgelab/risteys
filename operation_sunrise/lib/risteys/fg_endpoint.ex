defmodule Risteys.FGEndpoint do
  @moduledoc """
  The FGEndpoint context.
  """
  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.Icd10
  alias Risteys.YearDistribution
  alias Risteys.AgeDistribution
  alias Risteys.MortalityParams
  alias Risteys.MortalityBaseline
  alias Risteys.MortalityCounts
  alias Risteys.CoxHR
  alias Risteys.Genomics
  alias Risteys.DrugStats
  alias Risteys.FGEndpoint.GeneticCorrelation
  alias Risteys.FGEndpoint.Correlation
  alias Risteys.FGEndpoint.Definition
  alias Risteys.FGEndpoint.DefinitionICD10
  alias Risteys.FGEndpoint.ExplainerStep
  alias Risteys.FGEndpoint.StatsCumulativeIncidence
  alias Risteys.FGEndpoint.CaseOverlapsFR

  # -- Endpoint --
  def list_endpoint_names() do
    Repo.all(from endpoint in Definition, select: endpoint.name)
  end

  def list_endpoints_ids() do
    Repo.all(from endpoint in Definition, select: {endpoint.id, endpoint.name})
    |> Enum.reduce(%{}, fn {id, name}, acc ->
      Map.put_new(acc, name, id)
    end)
  end

  def set_status!(endpoint_name, field, status) when is_binary(endpoint_name) do
    Repo.get_by!(Definition, name: endpoint_name)
    |> set_status!(field, status)
  end

  def set_status!(%Definition{} = endpoint, field, status) do
    attrs =
      case field do
        :upset_plot_fg -> %{status_upset_plot_fg: status}
        :upset_plot_fr -> %{status_upset_plot_fr: status}
        :upset_table_fg -> %{status_upset_table_fg: status}
        :upset_table_fr -> %{status_upset_table_fr: status}
      end

    Definition.changeset(endpoint, attrs)
    |> Repo.update!()
  end

  def get_core_endpoints() do
    Repo.all(from endpoint in Definition, where: endpoint.is_core, select: endpoint.name)
    |> Enum.into(MapSet.new())
  end

  def find_replacement_endpoints(endpoint) do
    cond do
      endpoint.is_core ->
        {:is_core, nil}

      not is_nil(endpoint.selected_core_id) ->
        {:selected_core, Repo.get!(Definition, endpoint.selected_core_id)}

      endpoint.reason_non_core == "exallc_priority" ->
        {:exallc_priority, find_exallc_replacement(endpoint)}

      true ->
        {:correlated, find_correlated_replacements(endpoint)}
    end
  end

  defp find_exallc_replacement(endpoint) do
    map_exallc =
      Repo.all(
        from endp in Definition,
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
          join: endp in Definition,
          on: corr.fg_endpoint_b_id == endp.id,
          where:
            corr.fg_endpoint_a_id == ^endpoint.id and
              corr.fg_endpoint_b_id != ^endpoint.id and
              corr.case_overlap_percent >= ^overlap_threshold and
              endp.is_core,
          select: %{name: endp.name},
          order_by: [desc: corr.case_overlap_percent],
          limit: ^max_results
      )

    case list_correlated do
      [] -> nil
      _ -> list_correlated
    end
  end

  def get_random_endpoint() do
    Repo.all(from endpoint in Definition, select: endpoint.name) |> Enum.random()
  end

  def search_icds(query, limit) do
    pattern = "%" <> query <> "%"

    query =
      from endpoint in Definition,
      join: assoc in DefinitionICD10,
      on: endpoint.id == assoc.fg_endpoint_id,
      join: icd in Icd10,
      on: assoc.icd10_id == icd.id,
      where: ilike(icd.code, ^pattern),
      group_by: endpoint.name,
      select: %{name: endpoint.name, icds: fragment("array_agg(?)", icd.code)},
      limit: ^limit

    Repo.all(query)
  end

  def search_longnames(query, limit) do
    pattern = "%" <> query <> "%"

    query =
      from endpoint in Definition,
      select: %{name: endpoint.name, longname: endpoint.longname},
      where: ilike(endpoint.longname, ^pattern),
      limit: ^limit

    Repo.all(query)
  end

  def search_names(query, limit) do
    pattern = "%" <> query <> "%"

    query =
      from endpoint in Definition,
      select: %{name: endpoint.name, longname: endpoint.longname},
      where: ilike(endpoint.name, ^pattern),
      limit: ^limit

    Repo.all(query)
  end

  def search_descriptions(query, limit) do
    pattern = "%" <> query <> "%"

    query =
      from endpoint in Definition,
      where: ilike(endpoint.description, ^pattern),
      select: %{name: endpoint.name, description: endpoint.description},
      limit: ^limit

    Repo.all(query)
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

    counts_FG = get_explainer_step_counts(endpoint, "FG")

    counts_FR = get_explainer_step_counts(endpoint, "FR")

    Enum.map(steps, fn step ->
      %{name: step_name} = step
      # nil or count as an integer
      count_FG = counts_FG[step_name]
      count_FR = counts_FR[step_name]

      # Map.put_new(step, :nindivs_post_step, count_FG)
      step = Map.put_new(step, :nindivs_post_step_FG, count_FG)
      step = Map.put_new(step, :nindivs_post_step_FR, count_FR)
      step
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

  defp parse_multi(endpoint) do
    multi = %{}
    mode = parse_mode(endpoint)
    filters = parse_registry_filters(endpoint)

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

    multi =
      if Enum.empty?(filters) do
        multi
      else
        Map.put(multi, :filter_registries, filters)
      end

    multi
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

  defp parse_registry_filters(endpoint) do
    # Order will be discarded since it will be used as Map keys
    registries = [
      :outpat_icd,
      :outpat_icd_exp,
      :outpat_oper,
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

    mark_no_suitable_code = "$!$"

    endpoint
    |> Map.take(registries)
    |> Map.merge(icd10s_exp)
    |> Enum.reject(fn {_registry, values} ->
      # For data coming from the database when ICD expansion lead to empty list
      is_nil(values) or values == [] or values == mark_no_suitable_code
    end)
    |> Enum.into(%{})
  end

  defp list_expanded_icd10s(endpoint) do
    # Return list of ICD10 if the rule was expanded in import step, otherwise an empty list.
    expanded =
      Repo.all(
        from assoc in Risteys.FGEndpoint.DefinitionICD10,
          join: endpoint in Definition,
          on: assoc.fg_endpoint_id == endpoint.id,
          join: icd10 in Icd10,
          on: assoc.icd10_id == icd10.id,
          where: assoc.fg_endpoint_id == ^endpoint.id,
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

  defp parse_main_only(endpoint) do
    not is_nil(endpoint.hd_mainonly) or not is_nil(endpoint.cod_mainonly)
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

  def get_count_registries(endpoint) do
    groups = %{
      outpat_icd: :prim_out,
      outpat_icd_exp: :prim_out,
      outpat_oper: :prim_out,
      hd_icd_10_atc: :inpat_outpat,
      hd_icd_10: :inpat_outpat,
      hd_icd_10_exp: :inpat_outpat,
      hd_icd_9: :inpat_outpat,
      hd_icd_8: :inpat_outpat,
      hd_icd_10_excl: :inpat_outpat,
      hd_icd_10_excl_exp: :inpat_outpat,
      hd_icd_9_excl: :inpat_outpat,
      hd_icd_8_excl: :inpat_outpat,
      cod_icd_10: :cod,
      cod_icd_10_exp: :cod,
      cod_icd_9: :cod,
      cod_icd_8: :cod,
      cod_icd_10_excl: :cod,
      cod_icd_10_excl_exp: :cod,
      cod_icd_9_excl: :cod,
      cod_icd_8_excl: :cod,
      oper_nom: :oper,
      oper_hl: :oper,
      oper_hp1: :oper,
      oper_hp2: :oper,
      kela_reimb: :reimb,
      kela_reimb_icd: :reimb,
      kela_reimb_icd_exp: :reimb,
      kela_atc: :purch,
      kela_vnro: :purch,
      canc_topo: :canc,
      canc_topo_excl: :canc,
      canc_morph: :canc,
      canc_morph_excl: :canc,
      canc_behav: :canc
    }
    steps = get_explainer_steps(endpoint)

    filters =
      steps
      |> Enum.find(fn %{name: name} -> name == :multi end)
      |> Map.fetch!(:data)
      |> Map.get(:filter_registries, %{})

    used =
      for filter <- Map.keys(filters) do
        Map.fetch!(groups, filter)
      end
      |> Enum.uniq()
      |> Enum.count()

    total =
      groups
      |> Map.values()
      |> Enum.uniq()
      |> Enum.count()

    %{total: total, used: used}
  end

  def upsert_explainer_step(attrs) do
    case Repo.get_by(ExplainerStep, fg_endpoint_id: attrs.fg_endpoint_id, step: attrs.step, dataset: attrs.dataset) do
      nil -> %ExplainerStep{}
      existing -> existing
    end
    |> ExplainerStep.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp get_explainer_step_counts(endpoint, dataset) do
    Repo.all(
      from ee in ExplainerStep,
        where: ee.fg_endpoint_id == ^endpoint.id and ee.dataset == ^dataset,
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

  # -- Handle excluded endpoints --
  def test_exclusion(endpoint_name) do
    endpoint = Repo.get_by!(Definition, name: endpoint_name)
    excl = endpoint.fr_excl

    %{excl: excl}
  end

  # -- Histograms --
  def get_age_histogram(endpoint_name, dataset) do
    get_histograms(endpoint_name, dataset, AgeDistribution)
  end

  def get_year_histogram(endpoint_name, dataset) do
    get_histograms(endpoint_name, dataset, YearDistribution)
  end

  def get_histograms(endpoint_name, dataset, distrib_module) do
    endpoint = Repo.get_by!(Definition, name: endpoint_name)

    Repo.all(
      from distrib in distrib_module,
        where:
          distrib.fg_endpoint_id == ^endpoint.id and
          distrib.dataset == ^dataset,
        select: {
          distrib.left,
          distrib.right,
          distrib.count
        },
        # the first data row in the DB has nil in the "left" column,
        # need to sort data to have the data from that row as first item of a list returned by the DB query
        order_by: [asc_nulls_first: distrib.left]
    )
    # convert a list of tuples returned by the DB query into a list of nested maps
    |> Enum.map(fn {left, right, count} ->
      %{
        "interval" => %{
          "left" => left,
          "right" => right
          },
        "count" => count
      }
    end)
  end

  # -- Correlation --
  def upsert_correlation(attrs) do
    case Repo.get_by(Correlation,
           fg_endpoint_a_id: attrs.fg_endpoint_a_id,
           fg_endpoint_b_id: attrs.fg_endpoint_b_id
         ) do
      nil -> %Correlation{}
      existing -> existing
    end
    |> Correlation.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def list_correlations(endpoint_name) do
    endpoint = Repo.get_by!(Definition, name: endpoint_name)

    Repo.all(
      from corr in Correlation,
        join: endpoint in Definition,
        on: corr.fg_endpoint_b_id == endpoint.id,
        where:
          corr.fg_endpoint_a_id == ^endpoint.id and
            corr.fg_endpoint_a_id != corr.fg_endpoint_b_id,
        select: %{
          fg_endpoint_b_id: corr.fg_endpoint_b_id,
          name: endpoint.name,
          longname: endpoint.longname,
          case_overlap_percent: corr.case_overlap_percent,
          case_overlap_N: corr.case_overlap_N,
          gws_hits: endpoint.gws_hits,
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

  def broader_endpoints(endpoint, limit \\ 5) do
    Repo.all(
      from corr in Correlation,
        join: endpoint in Definition,
        on: corr.fg_endpoint_b_id == endpoint.id,
        where:
          corr.fg_endpoint_a_id == ^endpoint.id and
            corr.fg_endpoint_a_id != corr.fg_endpoint_b_id and
            corr.shared_of_a == 1.0,
        order_by: [desc: corr.shared_of_b],
        limit: ^limit,
        select: endpoint
    )
  end

  def narrower_endpoints(endpoint, limit \\ 5) do
    Repo.all(
      from corr in Correlation,
        join: endpoint in Definition,
        on: corr.fg_endpoint_b_id == endpoint.id,
        where:
          corr.fg_endpoint_a_id == ^endpoint.id and
            corr.fg_endpoint_a_id != corr.fg_endpoint_b_id and
            corr.shared_of_b == 1.0,
        order_by: [desc: corr.shared_of_a],
        limit: ^limit,
        select: endpoint
    )
  end

  def list_variants_by_correlation(endpoint) do
    by_corr =
      Repo.all(
        from corr in Correlation,
          join: endpoint in Definition,
          on: corr.fg_endpoint_b_id == endpoint.id,
          where: corr.fg_endpoint_a_id == ^endpoint.id,
          select: %{
            corr_endpoint: endpoint.name,
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

  def delete_cumulative_incidence(endpoint_ids, dataset) do
    Repo.delete_all(
      from cumul_inc in StatsCumulativeIncidence,
        where: cumul_inc.fg_endpoint_id in ^endpoint_ids and cumul_inc.dataset == ^dataset
    )
  end

  def get_cumulative_incidence_plot_data(endpoint_name, dataset) do
    %{id: endpoint_id} = Repo.get_by(Definition, name: endpoint_name)

    # Values will be converted from [0, 1] to [0, 100]
    females = get_cumulinc_sex(endpoint_id, "female", dataset)
    males = get_cumulinc_sex(endpoint_id, "male", dataset)

    # Get value for CIF plot y-axis to scale to content
    # Get the max values of "value" for both females and males and take the max between them
    # and ceil to closest integer
    max_females = get_max_of_value(females)
    max_males = get_max_of_value(males)
    max_value = Enum.max([max_females, max_males])
    max_value = Float.ceil(max_value)

    %{
      females: females,
      males: males,
      max_value: max_value
    }
  end

  defp get_cumulinc_sex(endpoint_id, sex, dataset) do
    Repo.all(
      from stats in StatsCumulativeIncidence,
        where:
          stats.fg_endpoint_id == ^endpoint_id and
            stats.sex == ^sex and
            stats.dataset == ^dataset,
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

  defp get_max_of_value(list_of_maps) do
    # Input is a list of maps where keys are "age" and "value".
    # Make a list of values of the "value" key from the list of maps.
    # Below code line creates a list because a list is the default output of for.
    # Variable "age" is unused so it has an underscore prefix.
    values = for %{age: _age, value: value} <- list_of_maps, do: value

    # return max value of values
    # if there is no results, return 0.0 (need to be float for Float.ceil to work in later step)
    if values == [], do: 0.0, else: Enum.max(values)
  end

  # -- Interactive Mortality --
  def get_mortality_data(endpoint_name) do
    endpoint = Repo.get_by!(Definition, name: endpoint_name)
    mortality_data = %{name: endpoint.name, longname: endpoint.longname}

    # get sex-specific results and save in mortality_data map as key-value pairs, where key is :female or :male
    Enum.reduce ["female", "male"], mortality_data, fn sex, acc ->

      sex_specific_results = %{}

      # get sex-specific baseline cumulative hazards
      bch =
        Repo.all(
          from baseline in MortalityBaseline,
          where: baseline.fg_endpoint_id == ^endpoint.id
          and baseline.sex == ^sex,
          select: {
            baseline.age,
            baseline.baseline_cumulative_hazard
          }
        )

      # handle missing data
      sex_specific_results =
        case bch do
          [] ->  Map.put_new(sex_specific_results, :bch, nil)
          bch -> Map.put_new(sex_specific_results, :bch,  Enum.into(bch, %{}))
        end

      # get sex-specific covariate results
      sex_specific_results =
        Enum.reduce ["exposure", "birth_year"], sex_specific_results, fn covariate_name, acc ->

          covariate_data =
            Repo.one(
              from params in MortalityParams,
                where: params.fg_endpoint_id == ^endpoint.id and
                params.covariate == ^covariate_name and
                params.sex == ^sex,
                select: %{
                  coef: params.coef,
                  ci95_lower: params.ci95_lower,
                  ci95_upper: params.ci95_upper,
                  p_value: params.p_value,
                  mean: params.mean
                }
            )

          empty_map = %{
            coef: nil,
            ci95_lower: nil,
            ci95_upper: nil,
            p_value: nil,
            mean: nil
          }

          key = String.to_atom(covariate_name)

          case covariate_data do
            nil -> Map.put(acc, key, empty_map)
            covariate_data -> Map.put(acc, key, Enum.into(covariate_data, %{}))
          end
        end

      # get sex-specific case counts
      case_counts =
        Repo.one(
          from counts in MortalityCounts,
            where: counts.fg_endpoint_id == ^endpoint.id and
            counts.sex == ^sex,
            select: %{
              exposed: counts.exposed,
              exposed_cases: counts.exposed_cases
            }
          )

      empty_counts_map = %{
        exposed: nil,
        exposed_cases: nil
      }

      # save data or empty map to "sex_specific_results" map
      sex_specific_results =
        case case_counts do
          nil -> Map.put(sex_specific_results, :case_counts, empty_counts_map)
          case_counts -> Map.put(sex_specific_results, :case_counts, Enum.into(case_counts, %{}))
        end

      # save sex_specific_results to mortality_data map
      sex_key = String.to_atom(sex)

      Map.put_new(acc, sex_key, sex_specific_results)
    end
  end

  # -- Relationships --
  def get_relationships(endpoint_name) do
    endpoint = Repo.get_by!(Definition, name: endpoint_name)

    # template map to use to make sure every map has every field to avoid reference issues later
    template = %{
      fg_endpoint_b_id: nil,
      name: nil,
      longname: nil,
      fr_case_overlap_percent: nil,
      fr_case_overlap_N: nil,
      hr_ci_max: nil,
      hr_ci_min: nil,
      hr: nil,
      hr_str: nil,
      hr_pvalue_str: nil,
      hr_binned: nil,
      rg: nil,
      rg_se: nil,
      rg_str: nil,
      rg_pvalue_str: nil,
      rg_ci_min: nil,
      rg_ci_max: nil,
      rg_binned: nil,
      fg_case_overlap_percent: nil,
      fg_case_overlap_N: nil,
      gws_hits: nil,
      coloc_gws_hits: nil
    }

    # get FG correlations
    fg_correlations = list_correlations(endpoint_name)

    # First, create joined_results map based on template map and FG correlation results
    joined_results = Enum.reduce(fg_correlations, %{}, fn data_map, acc ->
      tmp =
        template
        |> Map.put(:name, data_map.name)
        |> Map.put(:longname, data_map.longname)
        |> Map.put(:fg_case_overlap_percent, round_and_str(data_map.case_overlap_percent, 2))
        |> Map.put(:fg_case_overlap_N, data_map.case_overlap_N)
        |> Map.put(:gws_hits, data_map.gws_hits)
        |> Map.put(:coloc_gws_hits, data_map.coloc_gws_hits)

      Map.put(acc, data_map.fg_endpoint_b_id, tmp)
    end)

    # get FR case overlaps
    # this returns a list of maps where each map has data for one endpoint pair, i.e. one row in the Relationships table
    fr_case_overlaps = get_case_overlaps(endpoint)
    # add results to a map that will join all results from all tables
    joined_results = join_results(fr_case_overlaps, "fr_case_overlaps", joined_results, template, endpoint.id)

    # get FR survival analysis results
    fr_associations = data_assocs(endpoint)
    joined_results = join_results(fr_associations, "fr_surv", joined_results, template)

    # get FR survival analysis HR extremity
    hr_outcome_distribs = hr_outcome_distribs(endpoint)
    joined_results = join_results(hr_outcome_distribs, "fr_surv_extremity", joined_results, template)

    # get FG genetic correlations
    fg_genetic_correlations = get_genetic_correlations(endpoint)
    joined_results = join_results(fg_genetic_correlations, "fg_gen_corr", joined_results, template)

    # get FG genetic correlations rg extremity
    rg_outcome_distribs = rg_outcome_distribs(endpoint)
    joined_results = join_results(rg_outcome_distribs, "fg_gen_corr_extremity", joined_results, template)

    # return a list of maps, where each map has all available results for one enpdpoint pair
    Map.values(joined_results)
  end

  def join_results(data_list, data_type, joined_results, template, current_endpoint_id \\ nil) do
    Enum.reduce(data_list, joined_results, fn data_map, acc ->
      # Format the data so that it has field "fg_endpoint_b_id" having the id of the endpoint of interest
      # and other field names match with the respective names in the template map
      data_map = format_data(data_map, data_type, current_endpoint_id)

      # If current endpoint in the given data list (i.e., the pair endpoint of the endpoint of current page) is found from
      # the joined reults, append reusults to the corresponding map, otherwise create a new map using the teplate map.
      # Template map is used when creating a new map to make sure that all maps have keys for all possible fields.
      # --> Join all results from all tables together
      case Map.get(acc, data_map.fg_endpoint_b_id) do
        nil ->
          # If map for current endpoint b is not found, results for the current endpoint pair have not been available
          # in FG correlations, which means that the map doesn't have name of the endpoint b and it needs to be added.
          # Name and longname are added here to avoid any unnecassary enumeration throught the data maps
          name_map = Repo.one(
            from definition in Definition,
              where: definition.id == ^data_map.fg_endpoint_b_id,
              select: %{
                name: definition.name,
                longname: definition.longname
              }
          )

          tmp = Map.merge(template, name_map)
          tmp = Map.merge(tmp, data_map)

          Map.put(acc, tmp.fg_endpoint_b_id, tmp)
        map ->
          Map.put(acc, data_map.fg_endpoint_b_id, Map.merge(map, data_map))
      end
    end)
  end

  defp format_data(map, data_type, current_endpoint_id) do
    case data_type do
      "fr_case_overlaps" ->
        id = if map.fg_endpoint_b_id != current_endpoint_id, do: map.fg_endpoint_b_id, else: map.fg_endpoint_a_id

        %{
          fg_endpoint_b_id: id,
          fr_case_overlap_percent: round_and_str(map.case_overlap_percent, 2),
          fr_case_overlap_N: map.case_overlap_N
        }

      "fr_surv" ->
        # to get bonferroni corrected pvalues for FR HR values, threshold for significant pvalue is 0.05 / number of all converged analyses
        # 9773 is number of all converged FR survival analyses in the R10 input data file
        p_threshold = 0.05/ 9773
        %{
          fg_endpoint_b_id: map.outcome_id,
          hr_ci_max: round_and_str(map.ci_max, 2),
          hr_ci_min: round_and_str(map.ci_min, 2),
          hr: map.hr,
          hr_str: round_and_str(map.hr, 2),
          hr_pvalue_str: pvalue_star(map.pvalue, p_threshold)
        }

      "fr_surv_extremity" ->
        %{
          fg_endpoint_b_id: map.endpoint_id,
          hr_binned: map.percent_rank
        }

      "fg_gen_corr" ->
        %{
          fg_endpoint_b_id: map.fg_endpoint_b_id,
          rg: map.rg,
          rg_str: round_and_str(map.rg, 2),
          rg_ci_min: round_and_str(get_95_ci(map.rg, map.rg_se, "lower"), 2),
          rg_ci_max: round_and_str(get_95_ci(map.rg, map.rg_se, "upper"), 2),
          rg_pvalue_str: pvalue_star(map.rg_pvalue, 1.0e-6) # 0.000001 is threshold for significant p-value for FG genetic correlations
        }

      "fg_gen_corr_extremity" ->
        %{
          fg_endpoint_b_id: map.endpoint_id,
          rg_binned: map.percent_rank
        }

      _ ->
        raise "Given data type for formatting data doesn't match with any of the allowed keywords for data format."
    end
  end

  defp data_assocs(endpoint) do
    query =
      from assoc in CoxHR,
        join: prior in Definition,
        on: assoc.prior_id == prior.id,
        join: outcome in Definition,
        on: assoc.outcome_id == outcome.id,
        where: assoc.prior_id == ^endpoint.id,
        order_by: [desc: assoc.hr],
        select: %{
          prior_id: prior.id,
          outcome_id: outcome.id,
          outcome_name: outcome.name,
          outcome_longname: outcome.longname,
          hr: assoc.hr,
          ci_min: assoc.ci_min,
          ci_max: assoc.ci_max,
          pvalue: assoc.pvalue,
        }
    Repo.all(query)
  end

  defp get_case_overlaps(endpoint) do
    # each FR endpoint case overlap pair is saved in the DB only once, because a --> b is same as b --> a
    # --> need to query the data so that get all results for a given endpoint, regardless whether it's
    # saved in the DB as endpoint_a or endpoint_b -> get all pairs and get correct "endpoint b" id later when formatting data
    Repo.all(
      from case_overlap in CaseOverlapsFR,
        where:
          (case_overlap.fg_endpoint_a_id == ^endpoint.id or
          case_overlap.fg_endpoint_b_id == ^endpoint.id) and
          case_overlap.fg_endpoint_a_id != case_overlap.fg_endpoint_b_id,
        select: %{
          fg_endpoint_a_id: case_overlap.fg_endpoint_a_id,
          fg_endpoint_b_id: case_overlap.fg_endpoint_b_id,
          case_overlap_N: case_overlap.case_overlap_N,
          case_overlap_percent: case_overlap.case_overlap_percent,
        }
    )
  end

  def get_genetic_correlations(endpoint) do
    Repo.all(
      from gen_corr in GeneticCorrelation,
        where:
          gen_corr.fg_endpoint_a_id == ^endpoint.id and
          gen_corr.fg_endpoint_a_id != gen_corr.fg_endpoint_b_id,
        select: %{
          fg_endpoint_b_id: gen_corr.fg_endpoint_b_id,
          fg_endpoint_a_id: gen_corr.fg_endpoint_a_id,
          rg: gen_corr.rg,
          rg_se: gen_corr.se,
          rg_pvalue: gen_corr.pvalue,
        }
    )
  end

  defp hr_outcome_distribs(endpoint) do
    # at least that amount for a meaningful distribution
    min_count = 30

    percs =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        select: %{
          prior_id: c.prior_id,
          outcome_id: c.outcome_id,
          percent_rank:
            fragment(
              "percent_rank() OVER (PARTITION BY ? ORDER BY ?)",
              c.outcome_id,
              c.hr
            )
        }

    counts =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        group_by: c.outcome_id,
        select: %{
          outcome_id: c.outcome_id,
          count: count()
        }

    Repo.all(
      from endpoint in subquery(percs),
        join: cnt in subquery(counts),
        on: endpoint.outcome_id == cnt.outcome_id,
        where: endpoint.prior_id == ^endpoint.id and cnt.count > ^min_count,
        select: %{
          endpoint_id: endpoint.outcome_id,
          percent_rank: endpoint.percent_rank
        }
    )
  end

  defp rg_outcome_distribs(endpoint) do
    # at least that amount for a meaningful distribution
    min_count = 30

    percs =
      from c in GeneticCorrelation,
        select: %{
          prior_id: c.fg_endpoint_a_id,
          outcome_id: c.fg_endpoint_b_id,
          percent_rank:
            fragment(
              "percent_rank() OVER (PARTITION BY ? ORDER BY ?)",
              c.fg_endpoint_b_id,
              c.rg
            )
        }

    counts =
      from c in GeneticCorrelation,
        group_by: c.fg_endpoint_b_id,
        select: %{
          outcome_id: c.fg_endpoint_b_id,
          count: count()
        }

    Repo.all(
      from endpoint in subquery(percs),
        join: cnt in subquery(counts),
        on: endpoint.outcome_id == cnt.outcome_id,
        where: endpoint.prior_id == ^endpoint.id and cnt.count > ^min_count,
        select: %{
          endpoint_id: endpoint.outcome_id,
          percent_rank: endpoint.percent_rank
        }
    )
  end

  defp round_and_str(number, precision) do
    case number do
      nil -> nil
      "-" -> "-"
      _ -> :io_lib.format("~.#{precision}. f", [number]) |> to_string()
    end
  end

  defp pvalue_star(pvalue, p_threshold) do
    # statistically significant p-values are presented by "*"
    cond do
      is_nil(pvalue) ->
        nil
      pvalue <= p_threshold ->
        "*"
      true ->
         ""
    end
  end

  def get_95_ci(estimate, se, direction) do
    if !is_nil(estimate) and !is_nil(se) do
      case direction do
        # 1.96 is z-score for 95% confidence intervals
        "lower" -> estimate - 1.96 * se
        "upper" -> estimate + 1.96 * se
        _ -> nil
      end
    end
  end

  # --- Drug statistics
  def has_drug_stats?(endpoint) do
    stat_count =
      Repo.one(
        from dstats in DrugStats,
          where: dstats.fg_endpoint_id == ^endpoint.id,
          select: count()
      )

    stat_count > 0
  end
end
