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
      age: Enum.random(25..63) 
    }
  end
end
