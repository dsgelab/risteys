defmodule Risteys.Repo.Migrations.CreateLabTestStatsDistributionsLabValues do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_distributions_lab_values) do
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all), null: false

      # Data structure for distributions:
      #   [
      #     %{
      #       "measurement_unit" => "some unit" Str,
      #       "bins" => [
      #         %{"bin" => "x value" Str, "npeople" => N Int, "nrecords" => N Int},
      #         ...
      #       ],
      #       "breaks" => ["x value 1" Str, "x value 2" Str, ...]
      #     },
      #     ...
      #   ]
      add :distributions, {:array, :map}, null: false

      timestamps()
    end

    create unique_index(:lab_test_stats_distributions_lab_values, [:omop_concept_dbid])
  end
end
