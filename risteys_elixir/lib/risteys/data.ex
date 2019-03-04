defmodule Risteys.Data do
  @fake_indivs "assets/data/fake_indivs.json" |> File.read!() |> Jason.decode!()

  def build(code) do
    # splits:
    # - most common associated comorbidities
    # - age brackets
    # - sex
    metrics = [
      "C3_CANCER",
      "E4_DMNAS",
      "I9_K_CARDIAC"
    ]

    %{"name" => filter_name, "filters" => user_filter} = Risteys.Popfilter.default_filters()

    user_filter =
      user_filter
      |> Risteys.Popfilter.filters_to_func()

    profiles = [
      {"diagnosed w/ " <> code, fn %{^code => code} -> code end},
      {"whole population", fn _indiv -> true end},
      {filter_name, user_filter}
    ]

    profile_names =
      profiles
      |> Enum.map(fn {name, _filter} -> name end)

    indivs =
      for {name, filter} <- profiles do
        filtered_indivs = Enum.filter(@fake_indivs, filter)
        {name, filtered_indivs}
      end

    data =
      for {name, filtered_indivs} <- indivs do
        for metric <- metrics do
          filtered_indivs
          |> Enum.filter(fn %{^metric => m} -> m end)
          |> length
        end
      end

    %{profiles: profile_names, metrics: metrics, table: data}
  end
end
