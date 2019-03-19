alias Risteys.{Repo, Phenocode}

"assets/data/aki_endpoints__expanded.csv"
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn %{
                  "NAME" => code,
                  "LONGNAME" => longname,
                  "INCLUDE" => _includes,
                  "HD_ICD_10" => hd_codes,
                  "COD_ICD_10" => cod_codes
                } ->
  hd_codes = String.split(hd_codes)
  cod_codes = String.split(cod_codes)

  phenocode = %Phenocode{
    code: code,
    cod_codes: cod_codes,
    hd_codes: hd_codes,
    longname: longname
  }

  Repo.insert!(phenocode)
end)
