defmodule Risteys.Data do
  import Ecto.Query
  alias Risteys.{Repo, HealthEvent, Phenocode}

  defp average(numbers) do
    {sum, count} =
      numbers
      |> Enum.reduce({0, 0}, fn n, {sum, count} ->
        {sum + n, count + 1}
      end)

    sum / count
  end

  defp filter_age(query, [mini, maxi]) do
    case [mini, maxi] do
      [nil, nil] ->
        query

      _ ->
        from he in query,
          where: he.age >= ^mini and he.age <= ^maxi
    end
  end

  defp count_prevalence([mini, maxi]) do
    query = from(he in HealthEvent,
      select: [he.sex, count()],
      group_by: he.sex,
      order_by: he.sex
    ) |> filter_age([mini, maxi])

    [[1, n_males], [2, n_females]] = Repo.all(query)

    [n_males, n_females]
  end

  defp mean_ages(code, [mini, maxi]) do
    from(e in HealthEvent,
      join: p in Phenocode,
      on: e.phenocode_id == p.id,
      where: p.code == ^code,
      select: [e.sex, count(e.eid), avg(e.age)],
      group_by: e.sex,
      order_by: [asc: :sex]
    )
    |> filter_age([mini, maxi])
  end

  defp last_event_death(code) do
    indivs =
      from he in HealthEvent,
        join: p in Phenocode,
        on: he.phenocode_id == p.id,
        where: p.code == ^code and he.death

    # NOTE(vincent) in SQL we would have used a "where he in
    # (select...)" instead of a join but at this time 2019-03-26 Ecto
    # doesn't support subquery in the where clause.  More info:
    # https://hexdocs.pm/ecto/Ecto.Query.html#subquery/2

    from he in HealthEvent,
      join: s in subquery(indivs),
      on: s.id == he.id,
      group_by: he.eid,
      select: [he.eid, max(he.dateevent)]
  end

  defp rehosp_by_sex(code, age_limits) do
    # 1. Get information for each individual
    query =
      from he in HealthEvent,
        join: p in Phenocode,
        on: he.phenocode_id == p.id,
        where: p.code == ^code,
        group_by: [he.eid, he.sex],
        select: %{eid: he.eid, sex: he.sex, count: count(), start_date: min(he.dateevent)}

    indivs =
      Repo.all(query |> filter_age(age_limits))
      |> Enum.reduce(%{}, fn %{eid: eid, sex: sex, count: count, start_date: date}, acc ->
        # NOTE(vincent) we substract 1 to the total number of event as we are
        # interested in the *re*hospitalization, that is: how many events after
        # the first hospitalization.
        data = %{sex: sex, count: count - 1, start_date: date}
        Map.put(acc, eid, data)
      end)

    # 2. Attribute an end date for each individual
    dead = Repo.all(last_event_death(code) |> filter_age(age_limits))

    query_nondead =
      from he in HealthEvent,
        join: p in Phenocode,
        where: he.phenocode_id == p.id and p.code == ^code and not he.death,
        select: he.eid

    nondead =
      Repo.all(query_nondead |> filter_age(age_limits))
      # TODO set correct date for end of study
      |> Enum.map(fn eid -> [eid, ~D[2020-12-31]] end)

    indivs =
      Enum.concat(dead, nondead)
      |> Enum.reduce(%{}, fn [eid, end_date], acc ->
        data =
          Map.fetch!(indivs, eid)
          |> Map.put(:end_date, end_date)

        Map.put(acc, eid, data)
      end)

    # 3. Compute the re-hospitalization metric
    male =
      indivs
      |> Stream.filter(fn {_eid, %{sex: sex}} -> sex == 1 end)
      |> compute_rehosp

    female =
      indivs
      |> Stream.filter(fn {_eid, %{sex: sex}} -> sex == 2 end)
      |> compute_rehosp

    all = compute_rehosp(indivs)

    %{all: all, male: male, female: female}
  end

  defp compute_rehosp(indivs) do
    indivs
    |> Enum.map(fn {_eid, %{count: count, start_date: start_date, end_date: end_date}} ->
      case count do
        0 ->
          0

        _ ->
          days = Date.diff(end_date, start_date)

          case days do
            0 ->
              0

            _ ->
              years = days / 365.25
              count / years
          end
      end
    end)
    |> average
  end

  defp case_fatalities(code, age_limits) do
    indivs =
      from he in HealthEvent,
        join: p in Phenocode,
        on: he.phenocode_id == p.id,
        group_by: he.eid,
        select: %{eid: he.eid, first_event: min(he.dateevent)},
        where: p.code == ^code

    indivs = filter_age(indivs, age_limits)

    fatalities =
      Repo.all(
        from he in HealthEvent,
          join: s in subquery(indivs),
          on: he.eid == s.eid,
          select: %{
            eid: he.eid,
            sex: he.sex,
            case_fatality: he.death and max(he.dateevent) - s.first_event < 365.25 * 10
          },
          group_by: [he.eid, he.sex, he.death, s.first_event]
      )

    count_fatality = fn %{case_fatality: fatality}, {lived, died} ->
      case fatality do
        false -> {lived + 1, died}
        true -> {lived, died + 1}
      end
    end

    {female_lived, female_died} =
      fatalities
      |> Stream.filter(fn %{sex: sex} -> sex == 2 end)
      |> Enum.reduce({0, 0}, count_fatality)

    {male_lived, male_died} =
      fatalities
      |> Stream.filter(fn %{sex: sex} -> sex == 1 end)
      |> Enum.reduce({0, 0}, count_fatality)

    %{
      female: female_died / female_lived,
      male: male_died / male_lived,
      all: (female_died + male_died) / (female_lived + male_lived)
    }
  end

  defp get_stats(code, [age_mini, age_maxi]) do
    [[1, n_males, age_males], [2, n_females, age_females]] =
      Repo.all(mean_ages(code, [age_mini, age_maxi]))

    [total_males, total_females] = count_prevalence([age_mini, age_maxi])
    prevalence_male = n_males / total_males
    prevalence_female = n_females / total_females
    prevalence_all = (n_males + n_females) / (total_males + total_females)

    %{
      male: rehosp_males,
      female: rehosp_females,
      all: rehosp_all
    } = rehosp_by_sex(code, [age_mini, age_maxi])

    %{
      male: case_fatality_males,
      female: case_fatality_females,
      all: case_fatality_all
    } = case_fatalities(code, [age_mini, age_maxi])

    if n_males > 5 and n_females > 5 do
      results = %{
        all: %{
          nevents: n_males + n_females,
	  prevalence: prevalence_all,
          mean_age: (n_males * age_males + n_females * age_females) / (n_males + n_females),
          rehosp: rehosp_all,
          case_fatality: case_fatality_all
        },
        male: %{
          nevents: n_males,
	  prevalence: prevalence_male,
          mean_age: age_males,
          rehosp: rehosp_males,
          case_fatality: case_fatality_males
        },
        female: %{
          nevents: n_females,
	  prevalence: prevalence_female,
          mean_age: age_females,
          rehosp: rehosp_females,
          case_fatality: case_fatality_females
        }
      }

      {:ok, results}
    else
      {:error, "not enough data"}
    end
  end

  def stats_by_sex(code), do: get_stats(code, [nil, nil])

  def stats_by_sex(code, [age_mini, age_maxi]) do
    get_stats(code, [age_mini, age_maxi])
  end
end
