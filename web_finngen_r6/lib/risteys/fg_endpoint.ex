defmodule Risteys.FGEndpoint do
  @moduledoc """
  The FGEndpoint context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.Phenocode

  alias Risteys.FGEndpoint.Correlation

  # -- Correlation --
  def upsert_correlation(attrs) do
    case Repo.get_by(Correlation,
           phenocode_a_id: attrs.phenocode_a_id,
           phenocode_b_id: attrs.phenocode_b_id
         ) do
      nil -> %Correlation{}
      existing -> existing
    end
    |> Correlation.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def list_correlations(phenocode_name) do
    phenocode = Repo.get_by!(Phenocode, name: phenocode_name)
    Repo.all(
      from corr in Correlation,
        join: pp in Phenocode,
        on: corr.phenocode_b_id == pp.id,
        order_by: [desc_nulls_last: pp.gws_hits],
        where:
          corr.phenocode_a_id == ^phenocode.id and
            corr.phenocode_a_id != corr.phenocode_b_id,
        select: %{
          name: pp.name,
          longname: pp.longname,
          case_ratio: corr.case_ratio,
          gws_hits: pp.gws_hits,
          coloc_gws_hits_same_dir: corr.coloc_gws_hits_same_dir,
          coloc_gws_hits_opp_dir: corr.coloc_gws_hits_opp_dir,
          rel_beta: corr.rel_beta
        }
    )
  end

  def broader_endpoints(phenocode, limit \\ 5) do
    Repo.all(
      from corr in Correlation,
        join: pp in Phenocode,
        on: corr.phenocode_b_id == pp.id,
        where:
          corr.phenocode_a_id == ^phenocode.id and
            corr.phenocode_a_id != corr.phenocode_b_id and
            corr.shared_of_a == 1.0,
        order_by: [desc: corr.shared_of_b],
        limit: ^limit,
        select: pp
    )
  end

  def narrower_endpoints(phenocode, limit \\ 5) do
    Repo.all(
      from corr in Correlation,
        join: pp in Phenocode,
        on: corr.phenocode_b_id == pp.id,
        where:
          corr.phenocode_a_id == ^phenocode.id and
            corr.phenocode_a_id != corr.phenocode_b_id and
            corr.shared_of_b == 1.0,
        order_by: [desc: corr.shared_of_a],
        limit: ^limit,
        select: pp
    )
  end
end
