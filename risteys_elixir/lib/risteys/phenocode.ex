defmodule Risteys.Phenocode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phenocodes" do
    field :name, :string

    field :tags, :string
    field :level, :string
    field :omit, :string
    field :longname, :string
    field :sex, :string
    field :include, :string
    field :pre_conditions, :string
    field :conditions, :string
    # raw, unprocessed Outpat ICD_10
    field :outpat_icd, :string
    field :hd_mainonly, :string
    field :hd_icd_10_atc, :string
    # raw, unprocessed HD_ICD_10
    field :hd_icd_10, :string
    # raw, unprocessed HD_ICD_9
    field :hd_icd_9, :string
    field :hd_icd_8, :string
    # raw, unprocessed excl:HD_ICD_10
    field :hd_icd_10_excl, :string
    field :hd_icd_9_excl, :string
    field :hd_icd_8_excl, :string
    field :cod_mainonly, :string
    # raw, unprocessed COD_ICD_10
    field :cod_icd_10, :string
    # raw, unprocessed COD_ICD_9
    field :cod_icd_9, :string
    field :cod_icd_8, :string
    # raw, unprocessed excl:COD_ICD_10
    field :cod_icd_10_excl, :string
    field :cod_icd_9_excl, :string
    field :cod_icd_8_excl, :string
    field :oper_nom, :string
    field :oper_hl, :string
    field :oper_hp1, :string
    field :oper_hp2, :string
    field :kela_reimb, :string
    # raw, unprocessed Kela ICD_10
    field :kela_reimb_icd, :string
    field :kela_atc_needother, :string
    field :kela_atc, :string
    field :kela_vnro_needother, :string
    field :kela_vnro, :string
    field :canc_topo, :string
    field :canc_topo_excl, :string
    field :canc_morph, :string
    field :canc_morph_excl, :string
    field :canc_behav, :string
    field :special, :string
    field :version, :string
    field :parent, :string
    field :latin, :string

    field :category, :string
    field :ontology, {:map, {:array, :string}}
    # Description is populated from the ontology
    field :description, :string
    # Flag stating if this endpoint has a event count bump in 1998 due
    # to the introduction of the outpatient registry.
    field :outpat_bump, :boolean

    # Genome-wide significant hits
    field :gws_hits, :integer

    many_to_many :icd10s, Risteys.Icd10,
      join_through: Risteys.PhenocodeIcd10,
      # Delete ICD-10s not included in the update
      on_replace: :delete

    many_to_many :icd9s, Risteys.Icd9,
      join_through: Risteys.PhenocodeIcd9,
      # Delete ICD-9s not included in the update
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(phenocode, attrs) do
    phenocode
    |> cast(attrs, [
      :name,
      :tags,
      :level,
      :omit,
      :longname,
      :sex,
      :include,
      :pre_conditions,
      :conditions,
      :outpat_icd,
      :hd_mainonly,
      :hd_icd_10_atc,
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
      :kela_vnro_needother,
      :kela_vnro,
      :canc_topo,
      :canc_topo_excl,
      :canc_morph,
      :canc_morph_excl,
      :canc_behav,
      :special,
      :version,
      :parent,
      :latin,
      :category,
      :ontology,
      :description,
      :outpat_bump,
      :gws_hits
    ])
    |> validate_required([:name])
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
    |> validate_number(:gws_hits, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end

  defp allowed_ontology_types() do
    MapSet.new([
      "DOID",
      "EFO",
      "MESH",
      "SNOMED"
    ])
  end

  def parse_conditions(rule) do
    rule
    |> String.replace("!", "not ")
    |> String.replace("_NEVT", " number of events ")
    # Here we are using \n as a placeholder for splitting, it will not
    # appear in the end result.
    |> String.replace("&", "\nand ")
    |> String.replace("|", "\nor ")
    |> String.split("\n")
  end    
end
