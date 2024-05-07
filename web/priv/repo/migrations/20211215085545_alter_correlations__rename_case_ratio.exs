defmodule Risteys.Repo.Migrations.AlterCorrelationsRenameCaseRatio do
  use Ecto.Migration

  def change do
    rename table(:correlations), :case_ratio, to: :case_overlap
  end
end
