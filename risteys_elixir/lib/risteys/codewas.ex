defmodule Risteys.CodeWAS do
  @moduledoc """
  The CodeWAS context
  """

  import Ecto.Query

  require Logger

  alias Risteys.Repo
  alias Risteys.CodeWAS
  alias Risteys.FGEndpoint

  def get_cohort_stats(endpoint) do
    Repo.one(
      from cc in CodeWAS.Cohort,
      join: ee in FGEndpoint.Definition,
      on: cc.fg_endpoint_id == ee.id,
      where: ee.name == ^endpoint.name
    )
  end

  def list_codes(endpoint) do
    Repo.all(
      from cc in CodeWAS.Codes,
        join: ee in FGEndpoint.Definition,
        on: cc.fg_endpoint_id == ee.id,
        where: ee.name == ^endpoint.name,
        order_by: [desc: cc.nlog10p]
    )
  end

  def import_cohort_file(filepath) do
    endpoint_name = Path.basename(filepath, ".json")
    endpoint = Repo.get_by(FGEndpoint.Definition, name: endpoint_name)

    %{
      "n_cases" => n_cases,
      "n_controls" => n_controls,
      "per_cases_after_match" => percent_match_cases,
      "per_controls_after_match" => percent_match_controls
    } =
      filepath
      |> File.read!()
      |> Jason.decode!()

    n_matched_cases = floor(n_cases * percent_match_cases)
    n_matched_controls = floor(n_controls * percent_match_controls)

    case endpoint do
      nil ->
        Logger.warning(
          "Endpoint #{endpoint_name} not found in DB. Not importing CodeWAS cohort stats."
        )

      _ ->
        Logger.debug("Importing CodeWAS cohort data for endpoint #{endpoint_name}.")

        attrs = %{
          fg_endpoint_id: endpoint.id,
          n_matched_cases: n_matched_cases,
          n_matched_controls: n_matched_controls
        }

        {:ok, _schema} =
          %CodeWAS.Cohort{}
          |> CodeWAS.Cohort.changeset(attrs)
          |> Repo.insert()
    end
  end

  def import_codes_file(filepath, codes_info) do
    endpoint_name = Path.basename(filepath, ".csv")
    endpoint = Repo.get_by(FGEndpoint.Definition, name: endpoint_name)

    case endpoint do
      nil ->
        Logger.warning(
          "Endpoint #{endpoint_name} not found in DB. Not importing CodeWAS codes stats."
        )

      _ ->
        Logger.debug("Parsing and importing CodeWAS codes data for endpoint #{endpoint.name}.")

        filepath
        |> File.stream!()
        |> CSV.decode!(headers: true)
        |> Enum.map(fn record ->
          %{
            "FG_CODE1" => code1,
            "FG_CODE2" => code2,
            "FG_CODE3" => code3,
            "vocabulary_id" => vocabulary,
            "name_en" => description,
            "n_cases_yes" => n_cases,
            "n_controls_yes" => n_controls,
            "nlog10p" => nlog10p,
            "OR" => odds_ratio
          } = record

          code_key = {code1, code2, code3, vocabulary}

          default_code =
            [code1, code2, code3]
            |> Enum.reject(fn cc -> cc == "NA" end)
            |> Enum.join(", ")

          code = Map.get(codes_info, code_key, default_code)

          # Parsing floats
          {nlog10p_parsed, _remainder} = Float.parse(nlog10p)

          odds_ratio_parsed =
            case odds_ratio do
              # Elixir doesn't support ±infinity, so we use the max float instead
              "Inf" ->
                Float.max_finite()

              _ ->
                # Using Float.parse to handle both floats and integers, since our input data has both
                {float, _remainder} = Float.parse(odds_ratio)
                float
            end

          attrs = %{
            fg_endpoint_id: endpoint.id,
            code: code,
            description: description,
            vocabulary: vocabulary,
            odds_ratio: odds_ratio_parsed,
            nlog10p: nlog10p_parsed,
            n_matched_cases: n_cases,
            n_matched_controls: n_controls
          }

          {:ok, _schema} =
            %CodeWAS.Codes{}
            |> CodeWAS.Codes.changeset(attrs)
            |> Repo.insert()
        end)
    end
  end

  def build_codes_info(filepath) do
    filepath
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Enum.reduce(%{}, fn row, acc ->
      %{
        "FG_CODE1" => fg_code1,
        "FG_CODE2" => fg_code2,
        "FG_CODE3" => fg_code3,
        "code" => code,
        "vocabulary_id" => vocabulary
      } = row

      key = {fg_code1, fg_code2, fg_code3, vocabulary}

      Map.put(acc, key, code)
    end)
  end
end
