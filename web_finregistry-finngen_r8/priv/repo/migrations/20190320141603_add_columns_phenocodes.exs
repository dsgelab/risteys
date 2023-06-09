defmodule Risteys.Repo.Migrations.AddColumnsPhenocodes do
  use Ecto.Migration

  def change do
    rename table(:phenocodes), :hd_codes, to: :hd_icd_10
    rename table(:phenocodes), :cod_codes, to: :cod_icd_10

    alter table(:phenocodes) do
      add :tags, :string
      add :level, :string
      add :omit, :boolean
      add :sex, :integer
      add :include, :text
      add :pre_conditions, :string
      add :conditions, :string
      add :outpat_icd, :string
      add :hd_mainonly, :boolean
      add :hd_icd_9, {:array, :string}
      add :hd_icd_8, {:array, :string}
      add :hd_icd_10_excl, {:array, :string}
      add :hd_icd_9_excl, {:array, :string}
      add :hd_icd_8_excl, {:array, :string}
      add :cod_mainonly, :boolean
      add :cod_icd_9, {:array, :string}
      add :cod_icd_8, {:array, :string}
      add :cod_icd_10_excl, {:array, :string}
      add :cod_icd_9_excl, {:array, :string}
      add :cod_icd_8_excl, {:array, :string}
      add :oper_nom, {:array, :string}
      add :oper_hl, {:array, :string}
      add :oper_hp1, {:array, :string}
      add :oper_hp2, {:array, :string}
      add :kela_reimb, {:array, :string}
      add :kela_reimb_icd, {:array, :string}
      add :kela_atc_needother, :string
      add :kela_atc, {:array, :string}
      add :canc_topo, {:array, :string}
      add :canc_morph, :string
      add :canc_behav, :integer
      add :special, :string
      add :version, :string
      add :source, :string
      add :pheweb, :boolean
    end
  end
end
