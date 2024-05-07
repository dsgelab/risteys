defmodule Risteys.Repo.Migrations.AlterPhenocodesIcd9Array do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      # NOTE(vincent) not using 'modify' here as it fails to cast from string to any other type
      remove :hd_icd_9, :string
      add :hd_icd_9, {:array, :string}

      remove :cod_icd_9, :string
      add :cod_icd_9, {:array, :string}
    end
  end
end
