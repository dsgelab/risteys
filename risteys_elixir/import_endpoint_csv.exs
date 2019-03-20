# Import endpoint (aka Phenocode) information.
#
# The endpoint Excel file has to be first exported to CSV.
#
# Then the regexes in it are expanded.
# At this time it is done using the sre_yield python library.
# Another, more meaningful, approach would be to get a list of matches by using
# each regex against the full list of ICD codes.
#
# After that, this script can be used.
# 1. Parse the CSV file
# 2. Put the data from a CSV line to an Ecto schema
# 3. Insert data in database

alias Risteys.{Repo, Phenocode}

"assets/data/aki_endpoints__expanded.csv"
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.map(fn %{
                  "NAME" => code,
                  "LONGNAME" => longname,
                  "INCLUDE" => _includes,
                  "HD_ICD_10" => hd_codes,
                  "COD_ICD_10" => cod_codes
                } ->
  hd_codes = String.split(hd_codes)
  cod_codes = String.split(cod_codes)

  %Phenocode{
    code: code,
    cod_codes: cod_codes,
    hd_codes: hd_codes,
    longname: longname
  }
end)
|> Stream.take(100)  # NOTE take only of subset for development purpose
|> Enum.each(&Repo.insert!(&1))
