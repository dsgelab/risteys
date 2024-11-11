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
    {omop_concept_id_n_matched_keywords, cost_omop_concept_id_keywords} =
      cost_lab_test_attribute_omop_concept_id(lab_test, user_keywords)

    {list_test_names_n_matched_keywords, cost_list_test_names_keywords} =
      cost_lab_test_attribute_list_test_names(lab_test, user_keywords)

    {omop_concept_name_n_matched_keywords, cost_omop_concept_name_keywords} =
      cost_lab_test_attribute_omop_concept_name(lab_test, user_keywords)

    cost_n_matched_keywords =
      -Enum.max([
        omop_concept_id_n_matched_keywords,
        list_test_names_n_matched_keywords,
        omop_concept_name_n_matched_keywords
      ])

    %{
      record: lab_test,
      features_costs: [
        # Cost of N matched keywords
        cost_n_matched_keywords,
        # Costs by attribute:
        [
          cost_omop_concept_id_keywords,
          cost_list_test_names_keywords,
          cost_omop_concept_name_keywords
        ],
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
    {name_n_matched_keywords, cost_name_keywords} =
      cost_endpoint_attribute_name(endpoint, user_keywords)

    {longname_n_matched_keywords, cost_longname_keywords} =
      cost_endpoint_attribute_longname(endpoint, user_keywords)

    cost_n_matched_keywords =
      -Enum.max([
        name_n_matched_keywords,
        longname_n_matched_keywords
      ])

    %{
      record: endpoint,
      features_costs: [
        cost_n_matched_keywords,
        # Costs by attribute:
        [
          cost_name_keywords,
          cost_endpoint_icd_codes(endpoint, user_keywords),
          cost_longname_keywords,
          cost_icd_descriptions(endpoint, user_keywords)
        ],
        # Features that don't depend on the user's keywords
        cost_endpoint_n_cases(endpoint),
        cost_endpoint_n_gws_hits(endpoint)
      ]
    }
  end

  defp rank(results) do
    Enum.sort_by(results, fn %{features_costs: features_costs} -> features_costs end)
  end

  defp cost_lab_test_attribute_omop_concept_id(lab_test, user_keywords) do
    cost_attribute(user_keywords, lab_test.omop_concept_id)
  end

  defp cost_lab_test_attribute_omop_concept_name(lab_test, user_keywords) do
    cost_attribute(user_keywords, lab_test.omop_concept_name)
  end

  defp cost_lab_test_attribute_list_test_names(lab_test, user_keywords) do
    cost_attribute(user_keywords, lab_test.list_test_names)
  end

  defp cost_endpoint_attribute_name(endpoint, user_keywords) do
    cost_attribute(user_keywords, endpoint.name)
  end

  defp cost_endpoint_attribute_longname(endpoint, user_keywords) do
    cost_attribute(user_keywords, endpoint.longname)
  end

  defp cost_endpoint_icd_codes(endpoint, user_keywords) do
    all_icds =
      MapSet.new(endpoint.icd10_codes)
      |> MapSet.union(MapSet.new(endpoint.icd9_codes))

    n_exact_matches =
      MapSet.new(user_keywords)
      |> MapSet.intersection(all_icds)
      |> MapSet.size()

    n_prefix_matches =
      for keyword <- user_keywords, reduce: 0 do
        acc ->
          prefix_length = String.length(keyword)

          icd_prefixes =
            all_icds
            |> Enum.map(fn icd -> String.slice(icd, 0, prefix_length) end)
            |> MapSet.new()

          if MapSet.member?(icd_prefixes, keyword) do
            acc + 1
          else
            acc
          end
      end

    [-n_exact_matches, -n_prefix_matches]
  end

  defp cost_icd_descriptions(endpoint, user_keywords) do
    n_keyword_found =
      for keyword <- user_keywords, reduce: 0 do
        acc ->
          in_icd10? = String.contains?(endpoint.icd10_descriptions, keyword)
          in_icd9? = String.contains?(endpoint.icd9_descriptions, keyword)

          if in_icd10? or in_icd9? do
            acc + 1
          else
            acc
          end
      end

    -n_keyword_found
  end

  defp cost_attribute(user_keywords, attribute_string) do
    keyword_costs =
      for keyword <- user_keywords do
        find_keyword_cost(keyword, attribute_string)
      end

    n_matched_keywords =
      keyword_costs
      |> Enum.reject(fn cost -> cost == @cost_infinity end)
      |> length()

    {n_matched_keywords, keyword_costs}
  end

  defp find_keyword_cost(keyword, string) do
    string = String.downcase(string)

    case find_substring_indices(string, keyword) do
      {nil, nil} ->
        @cost_infinity

      {index_in_string, index_in_word} ->
        [index_in_string, index_in_word]
    end
  end

  @doc """
  Find the index of substring within string, and the index of substring within the matched word
  in string.
  """
  def find_substring_indices(string, substring) do
    find_substring_indices(string, substring, 0, 0)
  end

  defp find_substring_indices(string, substring, index_in_string, index_in_word) do
    case string do
      "" ->
        {nil, nil}

      <<^substring::binary, _rest::binary>> ->
        {index_in_string, index_in_word}

      <<" ", rest::binary>> ->
        find_substring_indices(rest, substring, index_in_string + 1, 0)

      <<_char::utf8, rest::binary>> ->
        find_substring_indices(rest, substring, index_in_string + 1, index_in_word + 1)
    end
  end

  defp cost_endpoint_n_cases(endpoint) do
    case endpoint.n_cases do
      nil ->
        @cost_infinity

      nn ->
        scale_factor = 1_000
        # Setting to negative to set lower cost for higher N cases
        -div(nn, scale_factor)
    end
  end

  defp cost_endpoint_n_gws_hits(endpoint) do
    case endpoint.n_gws_hits do
      nil ->
        @cost_infinity

      nn ->
        nn
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
