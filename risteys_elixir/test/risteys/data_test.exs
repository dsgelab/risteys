defmodule Risteys.DataTest do
  use Risteys.DataCase

  setup do
    data_fixture("AAA01", 20)  # this will give us 10 men + 20 women

    :ok
  end

  test "group data by sex" do
    {:ok, result} = Risteys.Data.stats_by_sex("AAA01")

    assert %{
             all: %{nevents: _, mean_age: _, case_fatality: _, rehosp: _},
             male: %{nevents: _, mean_age: _, case_fatality: _, rehosp: _},
             female: %{nevents: _, mean_age: _, case_fatality: _, rehosp: _}
           } = result
  end
end
