defmodule Risteys.Repo.Migrations.AlterCorrelationsChangeVariantsDoe do
  use Ecto.Migration

  def change do
    rename table(:correlations), :rel_beta, to: :rel_beta_same_dir

    alter table(:correlations) do
      # The data will change, so we need to remove, not just rename
      remove :variants, {:array, :text}, []

      add :variants_same_dir, {:array, :text}, null: false, default: []
      add :variants_opp_dir, {:array, :text}, null: false, default: []
    end
  end
end
