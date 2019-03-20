defmodule Risteys.DataTest do
  use ExUnit.Case, async: true

  test "group data by sex", %{data: data} do
    {:ok, result} = Risteys.Data.group_by_sex(data)

    assert %{
             all: %{nevents: _, mean_age: _},
             male: %{nevents: _, mean_age: _},
             female: %{nevents: _, mean_age: _}
           } = result
  end

  test "filter out data" do
    data = Risteys.Data.fake_db("X00")

    result = Risteys.Data.filter_out(data, [30, 50])
    assert Enum.all?(result, fn %{age: age} -> age >= 30 and age <= 50 end)
  end
end
