defmodule Risteys.Repo.Migrations.AlterPhenocodesRmIcdsAddStatsOntologyArticle do
  use Ecto.Migration

  def up do
    alter table(:phenocodes) do
      remove :hd_icd_9
      remove :cod_icd_9
      remove :hd_icd_10
      remove :cod_icd_10
      remove :kela_reimb_icd
      add :distrib_year, {:map, :integer}
      add :distrib_age, {:map, :integer}
      add :validation_article, :text
      add :ontology, {:map, {:array, :string}}
      modify :code, :text
      modify :longname, :text
      modify :tags, :text
      modify :level, :text
      modify :include, :text
      modify :pre_conditions, :text
      modify :conditions, :text
      modify :outpat_icd, :text
      modify :hd_icd_8, :text
      modify :hd_icd_10_excl, :text
      modify :hd_icd_9_excl, :text
      modify :hd_icd_8_excl, :text
      modify :cod_icd_8, :text
      modify :cod_icd_10_excl, :text
      modify :cod_icd_9_excl, :text
      modify :cod_icd_8_excl, :text
      modify :oper_nom, :text
      modify :oper_hl, :text
      modify :oper_hp1, :text
      modify :oper_hp2, :text
      modify :kela_reimb, :text
      modify :kela_atc_needother, :text
      modify :kela_atc, :text
      modify :canc_topo, :text
      modify :canc_morph, :text
      modify :special, :text
      modify :version, :text
      modify :source, :text
    end
    rename table(:phenocodes), :code, to: :name
  end

  def down do
    alter table(:phenocodes) do
      add :hd_icd_9, {:array, :string}
      add :cod_icd_9, {:array, :string}
      add :hd_icd_10, {:array, :string}
      add :cod_icd_10, {:array, :string}
      add :kela_reimb_icd, {:array, :string}
      remove :distrib_year
      remove :distrib_age
      remove :validation_article
      remove :ontology
      modify :name, :string
      modify :longname, :string
      modify :tags, :string
      modify :level, :string
      modify :include, :string
      modify :pre_conditions, :string
      modify :conditions, :string
      modify :outpat_icd, :string
      modify :hd_icd_8, :string
      modify :hd_icd_10_excl, :string
      modify :hd_icd_9_excl, :string
      modify :hd_icd_8_excl, :string
      modify :cod_icd_8, :string
      modify :cod_icd_10_excl, :string
      modify :cod_icd_9_excl, :string
      modify :cod_icd_8_excl, :string
      modify :oper_nom, :string
      modify :oper_hl, :string
      modify :oper_hp1, :string
      modify :oper_hp2, :string
      modify :kela_reimb, :string
      modify :kela_atc_needother, :string
      modify :kela_atc, :string
      modify :canc_topo, :string
      modify :canc_morph, :string
      modify :special, :string
      modify :version, :string
      modify :source, :string
    end
    rename table(:phenocodes), :name, to: :code
  end

  def change do
    alter table(:phenocodes) do
    end
  end
end
