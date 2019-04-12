defmodule Risteys.DataTest do
  use Risteys.DataCase

  setup do
    # this will give us 10 men + 20 women
    data_fixture("AAA01", 20)

    :ok
  end

  test "group data by sex" do
    {:ok, result} = Risteys.Data.stats_by_sex("AAA01")

    assert %{
             all: %{nevents: _, prevalence: _, mean_age: _, case_fatality: _, rehosp: _},
             male: %{nevents: _, prevalence: _, mean_age: _, case_fatality: _, rehosp: _},
             female: %{nevents: _, prevalence: _, mean_age: _, case_fatality: _, rehosp: _}
           } = result
  end
end
