defmodule Risteys.Data do
  @fake_indivs  "assets/data/fake_indivs.json" |> File.read!() |> Jason.decode!()

  def build() do
    metrics = [
      "death",
      "asthma",
      "cancer",
      "diabetes",
    ]

    profiles = %{
      "profileA" => fn %{"chron" => chron} -> chron == true end,
      "profileB" => fn %{"chron" => chron} -> chron == false end
    }

    indivs =
      for {name, filter} <- profiles, into: %{} do
        filtered_indivs = Enum.filter(@fake_indivs, filter)
        {name, filtered_indivs}
      end

    data =
      for {name, filtered_indivs} <- indivs do
        for metric <- metrics do
          filtered_indivs
          |> Enum.filter(fn %{^metric => m} -> m == true end)
          |> length
        end
      end

    %{profiles: Map.keys(profiles), metrics: metrics, table: data}
  end
end
