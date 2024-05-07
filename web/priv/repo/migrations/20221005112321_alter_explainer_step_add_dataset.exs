defmodule Risteys.Repo.Migrations.AlterExplainerStepAddDataset do
  use Ecto.Migration

  def up do
    alter table(:endp_explainer_step) do
      add :dataset, :string
    end
    drop index(:endp_explainer_step, [:fg_endpoint_id, :step], name: :fg_endpoint_step)
    create unique_index(:endp_explainer_step, [:fg_endpoint_id, :step, :dataset], name: :fg_endpoint_step_dataset)
  end

  def down do
    drop index(:endp_explainer_step, [:fg_endpoint_id, :step, :dataset], name: :fg_endpoint_step_dataset)
    create unique_index(:endp_explainer_step, [:fg_endpoint_id, :step], name: :fg_endpoint_step)
    alter table(:endp_explainer_step) do
      remove :dataset
    end
  end
end
