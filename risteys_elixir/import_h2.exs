# Import h2 statistics
#
# Usage:
#     mix run import_h2.exs <csv-file-h2-results>
#
# where <csv-file-h2-results> is a CSV file containing the h2
# liability statistics for many endpoints.

require Logger

alias Risteys.{Repo, Phenocode}

Logger.configure(level: :info)

[h2_file] = System.argv()

h2_file
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn %{
                  "phenocode" => phenocode,
                  "h2_liab" => h2_liab,
                  "se_liab" => h2_liab_se
                } ->
  Logger.info("Importing h2 for #{phenocode}")

  case Repo.get_by(Phenocode, name: phenocode) do
    nil ->
      Logger.warn("phenocode #{phenocode} not found")

    pheno_cs ->
      h2 =
        pheno_cs
        |> Phenocode.changeset(%{
          h2_liab: h2_liab,
          h2_liab_se: h2_liab_se
        })
        |> Repo.update()

      case h2 do
        {:ok, _} ->
          Logger.debug("update ok")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end
  end
end)
