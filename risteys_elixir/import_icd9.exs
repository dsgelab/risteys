# Import ICD-9 codes into the database
#
# Usage:
# mix run import_icd9.exs <path-to-file>
#
# Where <path-to-file> points to the "icd9_SimoP.txt" file (originally provided by Aki).
# This file has the following shape:
#    ICD9	ICD9LYH	ICD9TXT
#    001	KOLERA	CHOLERA
#    0010A	KOLERA VIBR CHOLE O1	CHOLERA E VIBRIONE CHOLERAE (01)
#    0011A	KOLERA EL TOR (O1)	CHOLERA E VIBRIONE CHOLERAE EL TOR (01)

alias Risteys.{Repo, ICD9}

Logger.configure(level: :info)
[filepath | _ ] = System.argv

filepath
|> File.stream!()
|> CSV.decode!(separator: ?\t, headers: true)
|> Stream.map(fn %{"ICD9" => icd9, "ICD9TXT" => description} ->
  %ICD9{code: icd9, description: description}
end)
|> Enum.each(&Repo.insert!(&1))
