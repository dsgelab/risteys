defmodule Risteys.Repo.Migrations.CreateKeyFigures do
  use Ecto.Migration

  def change do
    create table(:key_figures) do
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :nindivs_all, :integer
      add :nindivs_female, :integer
      add :nindivs_male, :integer
      add :median_age_all, :float
      add :median_age_female, :float
      add :median_age_male, :float
      add :prevalence_all, :float
      add :prevalence_female, :float
      add :prevalence_male, :float
      add :dataset, :string

      timestamps()
    end

    create unique_index(:key_figures, [:fg_endpoint_id, :dataset], name: :key_figures_fg_endpoint_id_dataset)
  end
end
