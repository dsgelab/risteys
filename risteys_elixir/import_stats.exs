# Import the flattened data by endpoint in the database.

alias Risteys.{Repo, PhenocodeStats}

[filepath | _ ] = System.argv

stats =
  filepath
  |> File.read!()
  |> Jason.decode!()

stats
|> Enum.each(fn {endpoint, data} ->
  %{
    "common_stats" => common_stats,
    "year_distrib" => year_distrib,
    "age_distrib" => age_distrib,
    "longit" => longit,
} = data

  IO.inspect longit
end)
