defmodule Risteys.Genomics do
  @moduledoc """
  The Genomics context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.Genomics.Gene

  @doc """
  Insert or update a gene in the database.
  """
  def upsert_gene(attrs) do
    case Repo.get_by(Gene, ensid: attrs.ensid) do
      nil -> %Gene{}
      existing -> existing
    end
    |> Gene.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  List close genes to a variant.
  The variant is expected to be in the CPRA format:
  CHR-POS-REF-ALT
  """
  def list_closest_genes(variant_cpra) do
    [chr, pos, _ref, _alt] = String.split(variant_cpra, "-")
    pos = String.to_integer(pos)
    lookup_window = 50_000

    Repo.all(
      from gene in Gene,
        where:
          gene.start - ^lookup_window < ^pos and gene.stop + ^lookup_window > ^pos and
          gene.chromosome == ^chr,
	order_by: gene.start
    )
  end
end
