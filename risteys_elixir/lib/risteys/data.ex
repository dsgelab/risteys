defmodule Risteys.Data do
  def fake_db(code) do
    first = fake_indiv(code)

    Stream.unfold(first, fn acc -> {acc, fake_indiv(code)} end)
    |> Enum.take(100)
  end

  defp fake_indiv(code) do
    year = Enum.random(1998..2015)
    month = Enum.random(1..12)
    day = Enum.random(1..28)

    {:ok, dateevent} = Date.new(year, month, day)

    %{
      sex: Enum.random([1, 2]),
      death: Enum.random([0, 1]),
      icd: code,
      dateevent: dateevent,
      age: Enum.random(25..70)
    }
  end

  defp aggregate(data) do
    nevents = length(data)

    ages = Enum.map(data, fn %{age: age} -> age end)
    mean_age = Enum.sum(ages) / nevents

    %{nevents: nevents, mean_age: mean_age}
  end

  def group_by_sex(data) do
    all = data
    male = all |> Enum.filter(fn %{sex: sex} -> sex == 1 end)
    female = all |> Enum.filter(fn %{sex: sex} -> sex == 2 end)

    %{
      all: aggregate(all),
      male: aggregate(male),
      female: aggregate(female)
    }
  end

  def filter_out(data, [age_min, age_max]) do
    data
    |> Enum.filter(fn %{age: age} ->
      age >= age_min and
        age <= age_max
    end)
  end
end
