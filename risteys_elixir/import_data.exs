alias Risteys.{Repo, HealthEvent}

"assets/data/example_codes_for_risteys__uniq__nona.tsv"
|> File.stream!()
|> CSV.decode!(separator: ?\t, headers: true)
|> Stream.map(fn %{
                   "eid" => eid,
                   "sex" => sex,
                   "death" => death,
                   "icd" => icd,
                   "dateevent" => dateevent,
                   "age" => age
                 } ->
  death =
    if death == "0" do
      false
    else
      true
    end

  now =
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)

  %{
    eid: String.to_integer(eid),
    sex: String.to_integer(sex),
    death: death,
    icd: icd,
    dateevent: Date.from_iso8601!(dateevent),
    age: String.to_float(age),
    inserted_at: now,
    updated_at: now
  }
end)
|> Enum.chunk_every(8_000)
|> Enum.each(fn chunk -> Repo.insert_all(HealthEvent, chunk) end)
