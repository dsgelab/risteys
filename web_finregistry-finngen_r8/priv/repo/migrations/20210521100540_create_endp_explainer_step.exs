defmodule Risteys.Repo.Migrations.CreateEndpExplainerStep do
  use Ecto.Migration

  def change do
    create table(:endp_explainer_step) do
      add :phenocode_id, references(:phenocodes, on_delete: :delete_all), null: false
      add :step, :text, null: false
      add :nindivs, :integer, null: true

      timestamps()
    end

    create unique_index(:endp_explainer_step, [:phenocode_id, :step], name: :phenocode_step)
  end
end
