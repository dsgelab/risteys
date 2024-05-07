defmodule Risteys.Repo.Migrations.AlterDefinitionRenameUpsetStatus do
  use Ecto.Migration

  def change do
    rename table(:fg_endpoint_definitions), :status_upset_plot_FG, to: :status_upset_plot_fg
    rename table(:fg_endpoint_definitions), :status_upset_table_FG, to: :status_upset_table_fg
    rename table(:fg_endpoint_definitions), :status_upset_plot_FR, to: :status_upset_plot_fr
    rename table(:fg_endpoint_definitions), :status_upset_table_FR, to: :status_upset_table_fr
  end
end
