defmodule Risteys.Phenocode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phenocodes" do
    field :name, :string
    field :longname, :string
    field :tags, :string
    field :category, :string
    field :level, :string
    field :omit, :boolean
    field :sex, :integer
    field :include, :string
    field :pre_conditions, :string
    field :conditions, :string
    field :outpat_icd, :string
    field :hd_mainonly, :boolean
    field :hd_icd_8, :string
    field :hd_icd_10_excl, :string
    field :hd_icd_9_excl, :string
    field :hd_icd_8_excl, :string
    field :cod_mainonly, :boolean
    field :cod_icd_8, :string
    field :cod_icd_10_excl, :string
    field :cod_icd_9_excl, :string
    field :cod_icd_8_excl, :string
    field :oper_nom, :string
    field :oper_hl, :string
    field :oper_hp1, :string
    field :oper_hp2, :string
    field :kela_reimb, :string
    field :kela_atc_needother, :string
    field :kela_atc, :string
    field :canc_topo, :string
    field :canc_morph, :string
    field :canc_behav, :integer
    field :special, :string
    field :version, :string
    field :validation_article, :string
    field :ontology, {:map, {:array, :string}}
    # used for the search feature
    field :description, :string

    many_to_many :icd10s, Risteys.Icd10, join_through: Risteys.PhenocodeIcd10
    many_to_many :icd9s, Risteys.Icd9, join_through: Risteys.PhenocodeIcd9

    timestamps()
  end

  @doc false
  def changeset(phenocode, attrs) do
    phenocode
    |> cast(attrs, [
      :name,
      :longname,
      :tags,
      :category,
      :level,
      :omit,
      :sex,
      :include,
      :pre_conditions,
      :conditions,
      :outpat_icd,
      :hd_mainonly,
      :hd_icd_8,
      :hd_icd_10_excl,
      :hd_icd_9_excl,
      :hd_icd_8_excl,
      :cod_mainonly,
      :cod_icd_8,
      :cod_icd_10_excl,
      :cod_icd_9_excl,
      :cod_icd_8_excl,
      :oper_nom,
      :oper_hl,
      :oper_hp1,
      :oper_hp2,
      :kela_reimb,
      :kela_atc_needother,
      :kela_atc,
      :canc_topo,
      :canc_morph,
      :canc_behav,
      :special,
      :version,
      :validation_article,
      :ontology,
      :description
    ])
    |> validate_required([:name, :longname])
    |> validate_exclusion(:level, ["1"])
    |> validate_change(:omit, fn :omit, omit ->
      if omit do
        [omit: "cannot be true"]
      else
        []
      end
    end)
    |> validate_change(:ontology, fn :ontology, ontology ->
      allowed = allowed_ontology_types()

      ontology
      |> Enum.map(fn {type, _value} ->
        if type not in allowed do
          {:ontology, "#{type} not in #{inspect(allowed)}"}
        end
      end)
      |> Enum.reject(fn error -> is_nil(error) end)
    end)
    |> validate_change(:ontology, fn :ontology, ontology ->
      len = Map.get(ontology, "DOID", []) |> length()

      if len > 80 do
        [ontology: "Too many DOID: #{len} > 80"]
      else
        []
      end
    end)
    |> unique_constraint(:name)
  end

  def allowed_ontology_types() do
    MapSet.new([
      "DOID",
      "EFO",
      "MESH",
      "SNOMED"
    ])
  end
end
