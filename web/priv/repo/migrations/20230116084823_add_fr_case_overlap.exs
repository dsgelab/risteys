defmodule Risteys.Repo.Migrations.AddFrCaseOverlap do
  use Ecto.Migration

  def change do
    create table(:case_overlaps_fr) do
      add :fg_endpoint_a_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :fg_endpoint_b_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :case_overlap_N, :integer, null: false
      add :case_overlap_percent, :float, null: false

      timestamps()
    end

    create unique_index(:case_overlaps_fr, [:fg_endpoint_a_id, :fg_endpoint_b_id], name: :fr_case_overlaps_fg_endpoint_a_b)
  end
end
