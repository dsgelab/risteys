# This script import gene information in order to link variants to gene names.
#
# Input: JSON files with chromosome, start, stop and gene_name. File provided by Nicola C, pre-processed from Havana file.

alias Risteys.Genomics

require Logger

Logger.configure(level: :info)
[havana_genes | _] = System.argv()

havana_genes
|> File.read!()
|> Jason.decode!()
|> Enum.map(fn record ->
  %{
    "ID" => ensid,
    "chromosome" => chromosome,
    "start" => start,
    "stop" => stop,
    "gene_name" => name
  } = record

  chromosome = String.replace_prefix(chromosome, "chr", "")

  Genomics.upsert_gene(%{
    ensid: ensid,
    chromosome: chromosome,
    start: start,
    stop: stop,
    name: name
  })
end)
