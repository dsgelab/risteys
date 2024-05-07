defmodule Risteys.Repo.Migrations.AlterPhenocodesColsNoarray do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      modify :hd_icd_9, :string
      modify :hd_icd_8, :string
      modify :hd_icd_10_excl, :string
      modify :hd_icd_9_excl, :string
      modify :hd_icd_8_excl, :string

      modify :cod_icd_9, :string
      modify :cod_icd_8, :string
      modify :cod_icd_10_excl, :string
      modify :cod_icd_9_excl, :string
      modify :cod_icd_8_excl, :string

      modify :oper_nom, :string
      modify :oper_hl, :string
      modify :oper_hp1, :string
      modify :oper_hp2, :string

      modify :kela_reimb, :string
      modify :kela_atc, :string

      modify :canc_topo, :string
    end
  end
end
