defmodule Risteys.Repo.Migrations.AlterPhenocodeAddFields do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :hd_icd_10, :text
      add :hd_icd_9, :text
      add :cod_icd_10, :text
      add :cod_icd_9, :text
      add :kela_reimb_icd, :text
      add :kela_vnro_needother, :text
      add :kela_vnro, :text
      add :canc_morph_excl, :text
      add :parent, :text
    end
  end
end
