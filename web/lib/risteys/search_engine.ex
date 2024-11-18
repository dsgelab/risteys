defmodule Risteys.SearchEngine do
  # For missing value we want to give the maximum cost possible, which in Elixir
  # term ordering is the string type. This works because or other cost types are
  # either numbers or list of numbers, which are ordered before strings.
  @cost_infinity ""

  def search(user_query) do
    user_keywords = user_query |> String.downcase() |> String.split()

    # Find matching records
    lab_tests_matching_records = Risteys.LabTestStats.find_matching_records(user_keywords)

    endpoints_matching_records = Risteys.FGEndpoint.find_matching_records(user_keywords)

    # Compute costs of features for each record
    lab_tests_records_with_costs =
      lab_tests_matching_records
      |> Enum.map(fn lab_test -> compute_costs_lab_test(lab_test, user_keywords) end)

    endpoints_records_with_costs =
      endpoints_matching_records
      |> Enum.map(fn endpoint -> compute_costs_endpoint(endpoint, user_keywords) end)

    # Rank results, separately for lab tests and endpoints
    lab_tests_ranked =
      lab_tests_records_with_costs
      |> rank()

    endpoints_ranked =
      endpoints_records_with_costs
      |> rank()

    combine_results(lab_tests_ranked, endpoints_ranked)
  end

  defp compute_costs_lab_test(lab_test, user_keywords) do
    ordered_attributes = [
      :omop_concept_id,
      :list_test_names,
      :omop_concept_name
    ]

    {cost_n_matched_keywords, cost_attribute} =
      costs_n_keywords_attributes(user_keywords, lab_test, ordered_attributes)

    %{
      record: lab_test,
      features_costs: [
        # Cost of N matched keywords
        cost_n_matched_keywords,
        # Costs by attribute:
        cost_attribute,
        # Features independent of the user keywords
        cost_lab_test_npeople(lab_test),
        cost_lab_test_percent_people_with_two_plus_records(lab_test)
      ]
    }
  end

  defp cost_lab_test_npeople(lab_test) do
    scale_factor = 1_000
    -div(lab_test.omop_concept_npeople, scale_factor)
  end

  defp cost_lab_test_percent_people_with_two_plus_records(lab_test) do
    case lab_test.omop_concept_percent_people_with_two_plus_records do
      nil ->
        @cost_infinity

      nn ->
        -nn
    end
  end

  defp compute_costs_endpoint(endpoint, user_keywords) do
    ordered_attributes = [
      :icd10_codes,
      :icd9_codes,
      :longname,
      :name,
      :icd10_descriptions,
      :icd9_descriptions
    ]

    {cost_n_matched_keywords, cost_attribute} =
      costs_n_keywords_attributes(user_keywords, endpoint, ordered_attributes)

    %{
      record: endpoint,
      features_costs: [
        cost_n_matched_keywords,
        # Costs by attribute:
        cost_attribute,
        # Features that don't depend on the user's keywords
        cost_endpoint_n_gws_hits(endpoint),
        cost_endpoint_n_cases(endpoint)
      ]
    }
  end

  defp rank(results) do
    Enum.sort_by(results, fn %{features_costs: features_costs} -> features_costs end)
  end

  defp costs_n_keywords_attributes(user_keywords, result, ordered_attributes) do
    matches =
      for keyword <- user_keywords, attribute <- ordered_attributes do
        found? =
          Map.fetch!(result, attribute)
          |> String.downcase()
          |> String.contains?(keyword)

        {keyword, attribute, found?}
      end

    by_keyword =
      for {keyword, _attribute, found?} <- matches, reduce: %{} do
        acc ->
          n_found = Map.get(acc, keyword, 0)

          if found? do
            Map.put(acc, keyword, n_found + 1)
          else
            Map.put(acc, keyword, n_found)
          end
      end

    by_attribute =
      for {_keyword, attribute, found?} <- matches, reduce: %{} do
        acc ->
          n_found = Map.get(acc, attribute, 0)

          if found? do
            Map.put(acc, attribute, n_found + 1)
          else
            Map.put(acc, attribute, n_found)
          end
      end

    cost_n_matched_keywords =
      by_keyword
      |> Map.values()
      |> Enum.filter(fn count -> count > 0 end)
      |> length()

    cost_n_matched_keywords = -cost_n_matched_keywords

    attributes_with_all_keywords =
      by_attribute
      |> Map.filter(fn {_attribute, n_keywords_found} ->
        n_keywords_found == length(user_keywords)
      end)

    cost_attribute =
      Enum.find_index(ordered_attributes, fn attribute ->
        Map.has_key?(attributes_with_all_keywords, attribute)
      end)

    cost_attribute = cost_attribute || @cost_infinity

    {cost_n_matched_keywords, cost_attribute}
  end

  defp cost_endpoint_n_cases(endpoint) do
    case endpoint.n_cases do
      nil ->
        @cost_infinity

      nn ->
        # Setting to negative to set lower cost for higher N cases
        -nn
    end
  end

  defp cost_endpoint_n_gws_hits(endpoint) do
    case endpoint.n_gws_hits do
      nil ->
        @cost_infinity

      nn ->
        -div(nn, 10)
    end
  end

  defp combine_results(lab_tests_ranked, endpoints_ranked) do
    max_n_results_by_facet = 10

    lab_tests_have_more_results =
      Enum.count_until(lab_tests_ranked, max_n_results_by_facet + 1) > max_n_results_by_facet

    lab_tests_top_results = extract_top_records(lab_tests_ranked, max_n_results_by_facet)

    endpoints_have_more_results =
      Enum.count_until(endpoints_ranked, max_n_results_by_facet + 1) > max_n_results_by_facet

    endpoints_top_results = extract_top_records(endpoints_ranked, max_n_results_by_facet)

    %{
      lab_tests: %{
        have_more_results: lab_tests_have_more_results,
        top_results: lab_tests_top_results
      },
      endpoints: %{
        have_more_results: endpoints_have_more_results,
        top_results: endpoints_top_results
      }
    }
  end

  defp extract_top_records(results, top_n) do
    results
    |> Enum.map(fn %{record: record} -> record end)
    |> Enum.take(top_n)
  end
end
