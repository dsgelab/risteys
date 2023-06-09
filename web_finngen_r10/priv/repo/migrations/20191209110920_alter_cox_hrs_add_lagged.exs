defmodule Risteys.Repo.Migrations.AlterCoxHrsAddLagged do
  use Ecto.Migration

  def change do
    alter table(:cox_hrs) do
      add :lagged_hr_cut_year, :integer, null: false, default: 0
    end

    drop unique_index(:cox_hrs, [:prior_id, :outcome_id], name: :prior_outcome)
    create unique_index(:cox_hrs, [:prior_id, :outcome_id, :lagged_hr_cut_year], name: :prior_outcome_lagged)
  end
end
