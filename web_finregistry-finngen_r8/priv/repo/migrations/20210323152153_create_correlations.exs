defmodule Risteys.Repo.Migrations.CreateCorrelations do
  use Ecto.Migration

  def change do
    create table(:correlations) do
      add :phenocode_a_id, references(:phenocodes, on_delete: :delete_all), null: false
      add :phenocode_b_id, references(:phenocodes, on_delete: :delete_all), null: false

      add :case_ratio, :float
      add :shared_of_a, :float
      add :shared_of_b, :float
      add :coloc_gws_hits_same_dir, :integer
      add :coloc_gws_hits_opp_dir, :integer
      add :rel_beta, :float
      add :rel_beta_opp_dir, :float

      timestamps()
    end

    create unique_index(:correlations, [:phenocode_a_id, :phenocode_b_id], name: :phenocode_a_b)
  end
end
