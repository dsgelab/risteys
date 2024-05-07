defmodule Risteys.Repo.Migrations.AlterCorrelationsAddCaseOverlap_N do
  use Ecto.Migration

  def change do
    alter table(:correlations) do
      add :case_overlap_N, :integer
    end
    rename table(:correlations), :case_overlap, to: :case_overlap_percent
  end
end
