defmodule Risteys.Phenocode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phenocodes" do
    field :code, :string
    field :longname, :string
    field :tags, :string
    field :level, :string
    field :omit, :boolean
    field :sex, :integer
    field :include, :string
    field :pre_conditions, :string
    field :conditions, :string
    field :outpat_icd, :string
    field :hd_mainonly, :boolean
    field :hd_icd_10, {:array, :string}
    field :hd_icd_9, {:array, :string}
    field :hd_icd_8, :string
    field :hd_icd_10_excl, :string
    field :hd_icd_9_excl, :string
    field :hd_icd_8_excl, :string
    field :cod_mainonly, :boolean
    field :cod_icd_10, {:array, :string}
    field :cod_icd_9, {:array, :string}
    field :cod_icd_8, :string
    field :cod_icd_10_excl, :string
    field :cod_icd_9_excl, :string
    field :cod_icd_8_excl, :string
    field :oper_nom, :string
    field :oper_hl, :string
    field :oper_hp1, :string
    field :oper_hp2, :string
    field :kela_reimb, :string
    field :kela_reimb_icd, {:array, :string}
    field :kela_atc_needother, :string
    field :kela_atc, :string
    field :canc_topo, :string
    field :canc_morph, :string
    field :canc_behav, :integer
    field :special, :string
    field :version, :string
    field :source, :string
    field :pheweb, :boolean

    timestamps()
  end

  @doc false
  def changeset(phenocode, attrs) do
    phenocode
    |> cast(attrs, [
      :code,
      :longname,
      :tags,
      :level,
      :omit,
      :sex,
      :include,
      :pre_conditions,
      :conditions,
      :outpat_icd,
      :hd_mainonly,
      :hd_icd_10,
      :hd_icd_9,
      :hd_icd_8,
      :hd_icd_10_excl,
      :hd_icd_9_excl,
      :hd_icd_8_excl,
      :cod_mainonly,
      :cod_icd_10,
      :cod_icd_9,
      :cod_icd_8,
      :cod_icd_10_excl,
      :cod_icd_9_excl,
      :cod_icd_8_excl,
      :oper_nom,
      :oper_hl,
      :oper_hp1,
      :oper_hp2,
      :kela_reimb,
      :kela_reimb_icd,
      :kela_atc_needother,
      :kela_atc,
      :canc_topo,
      :canc_morph,
      :canc_behav,
      :special,
      :version,
      :source,
      :pheweb
    ])
    |> validate_required([:code, :longname])
    # TODO put validations when the data source is stable
    |> unique_constraint(:code)
  end
end
