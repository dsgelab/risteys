# Import events from an data extract.
#
# Before using this script, the data should pre-processed to make each line
# unique, as well as removing the N/A data.
#
# Then, this script can be used and will:
# 1. parse the data file
# 2. assign a random phenocode to each record.
#    (since the original data contains ICD-10 codes, not a phenocode)
# 3. take only the first few thousand records.
#    (otherwise it is a very long process)
# 4. insert data in database

alias Risteys.{Repo, Phenocode}
import Ecto.Query

Logger.configure(level: :info)

phenocodes = Repo.all(from(p in Phenocode))

"assets/data/example_codes_for_risteys__uniq__nona.tsv"
|> File.stream!()
|> CSV.decode!(separator: ?\t, headers: true)
|> Stream.map(fn %{
                   "eid" => eid,
                   "sex" => sex,
                   "death" => death,
                   "icd" => _icd,
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

  phenocode = Enum.random(phenocodes)

  health_event = %{
    eid: String.to_integer(eid),
    sex: String.to_integer(sex),
    death: death,
    dateevent: Date.from_iso8601!(dateevent),
    age: String.to_float(age),
    inserted_at: now,
    updated_at: now
  }

  Ecto.build_assoc(phenocode, :health_events, health_event)
end)
|> Stream.take(1_000)
|> Enum.each(&Repo.insert!(&1))
