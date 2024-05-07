

alias Risteys.{FGEndpoint.Definition, Repo, AgeDistribution, YearDistribution}
require Logger

Logger.configure(level: :info)

[distrib_filepath, distribution_type, dataset | _] = System.argv()

# test that valid arguments are given
if distribution_type != "age" and distribution_type != "year" do
  raise ArgumentError, message: "Type of distribution needs to be given as a second argument, either age or year"
end

if dataset != "FG" and dataset != "FR" do
  raise ArgumentError, message: "Dataset needs to be given as a third argument, either FG or FR."
end

Logger.info("Start importing #{distribution_type} distributions")

distrib_filepath
|> File.stream!()
|> CSV.decode!(headers: :true)
|> Enum.each(fn row ->
  %{
    "endpoint" => name,
    "sex" => sex,
    "left" => left,
    "right" => right,
    "count" => count
  } = row

  Logger.info("Handling data of #{name}, value of 'left': #{left}")

  # convert histogram bin values to correct datatype: nil or float
  left = if left == "-inf", do: nil, else: String.to_float(left)
  right = if right == "inf", do: nil, else: String.to_float(right)

  # Prevent distributions from being accidentially imported to incorrect distribution table
  # by checking that histogram bin edge values make sense with the given distribution type

  message_text =
    "Data import stopped.
    You're trying to import #{distribution_type} histogram data, but the input data
    has a histogram bin edge value of #{right}, which is not in the expected range.
    Please check your input data and the argument for distribution type."

  case distribution_type do
    "age" ->
      if right > 200 and !is_nil(right) do
        raise ArgumentError, message: message_text
      end
    "year" ->
      if right < 1000 and !is_nil(right) do
        raise ArgumentError, message: message_text
      end
  end

  # get enpoint definition data for endpoint id
  endpoint = Repo.get_by(Definition, name: name)

  # Get correct module
  distrib_module =
    if distribution_type == "age" do
      AgeDistribution
    else
      YearDistribution
    end

  # Import data to the DB
  case endpoint do
    nil ->
      Logger.warning("Endpoint #{name} not in the DB, skipping")
    endpoint ->
      distrib =
        case distribution_type do
          "age" -> %AgeDistribution{}
          "year" -> %YearDistribution{}
        end

        |> distrib_module.changeset(%{
          fg_endpoint_id: endpoint.id,
          sex: sex,
          left: left,
          right: right,
          count: String.to_integer(count),
          dataset: dataset
        })
        |> Repo.insert()

      case distrib do
        {:ok, _} ->
          Logger.info("Insert ok")
        {:error, changeset} ->
          Logger.warning(inspect(changeset))
      end
  end
end)
