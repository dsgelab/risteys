defmodule Risteys.Repo.Migrations.AlterDefinitionAddDatasetForUpsetStatus do
  use Ecto.Migration

  def change do
    alter table(:fg_endpoint_definitions) do
      add :status_upset_plot_FR, :string
      add :status_upset_table_FR, :string
    end
    rename table(:fg_endpoint_definitions), :status_upset_plot, to: :status_upset_plot_FG
    rename table(:fg_endpoint_definitions), :status_upset_table, to: :status_upset_table_FG
  end
end
