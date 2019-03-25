defmodule Risteys.Data do
  import Ecto
  import Ecto.Query
  alias Risteys.{Repo, HealthEvent, Phenocode}

  defp query_group_by_sex(code) do
    
    from e in HealthEvent,
      join: p in Phenocode,
      on: e.phenocode_id == p.id,
      where: p.code == ^code,
      select: [e.sex, count(e.eid), avg(e.age)],
      group_by: e.sex,
      order_by: [asc: :sex]
  end

  defp query_group_by_sex_filter_age(code, [mini, maxi]) do
    from e in query_group_by_sex(code),
      where: e.age >= ^mini and e.age <= ^maxi
  end

  defp get_results(code, [age_mini, age_maxi]) do
    query =
      case [age_mini, age_maxi] do
        [nil, nil] -> query_group_by_sex(code)
        _ -> query_group_by_sex_filter_age(code, [age_mini, age_maxi])
      end

    [[1, n_males, age_males], [2, n_females, age_females]] = Repo.all(query)

    if n_males > 5 and n_females > 5 do
      results = %{
        all: %{
          nevents: n_males + n_females,
          mean_age: (n_males * age_males + n_females * age_females) / (n_males + n_females)
        },
        male: %{
          nevents: n_males,
          mean_age: age_males
        },
        female: %{
          nevents: n_females,
          mean_age: age_females
        }
      }

      {:ok, results}
    else
      {:error, "not enough data"}
    end
  end

  def group_by_sex(code) do
    get_results(code, [nil, nil])
  end

  def group_by_sex(code, [age_mini, age_maxi]) do
    get_results(code, [age_mini, age_maxi])
  end
end
