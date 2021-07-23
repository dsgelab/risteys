defmodule Risteys.FGEndpointTest do
  use Risteys.DataCase

  alias Risteys.FGEndpoint

  describe "correlations" do
    alias Risteys.FGEndpoint.Correlation

    @valid_attrs %{case_ratio: 120.5, shared_of_a: 120.5, shared_of_b: 120.5}
    @update_attrs %{case_ratio: 456.7, shared_of_a: 456.7, shared_of_b: 456.7}
    @invalid_attrs %{case_ratio: nil, shared_of_a: nil, shared_of_b: nil}

    def correlation_fixture(attrs \\ %{}) do
      {:ok, correlation} =
        attrs
        |> Enum.into(@valid_attrs)
        |> FGEndpoint.create_correlation()

      correlation
    end

    test "list_correlations/0 returns all correlations" do
      correlation = correlation_fixture()
      assert FGEndpoint.list_correlations() == [correlation]
    end

    test "get_correlation!/1 returns the correlation with given id" do
      correlation = correlation_fixture()
      assert FGEndpoint.get_correlation!(correlation.id) == correlation
    end

    test "create_correlation/1 with valid data creates a correlation" do
      assert {:ok, %Correlation{} = correlation} = FGEndpoint.create_correlation(@valid_attrs)
      assert correlation.case_ratio == 120.5
      assert correlation.shared_of_a == 120.5
      assert correlation.shared_of_b == 120.5
    end

    test "create_correlation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = FGEndpoint.create_correlation(@invalid_attrs)
    end

    test "update_correlation/2 with valid data updates the correlation" do
      correlation = correlation_fixture()
      assert {:ok, %Correlation{} = correlation} = FGEndpoint.update_correlation(correlation, @update_attrs)
      assert correlation.case_ratio == 456.7
      assert correlation.shared_of_a == 456.7
      assert correlation.shared_of_b == 456.7
    end

    test "update_correlation/2 with invalid data returns error changeset" do
      correlation = correlation_fixture()
      assert {:error, %Ecto.Changeset{}} = FGEndpoint.update_correlation(correlation, @invalid_attrs)
      assert correlation == FGEndpoint.get_correlation!(correlation.id)
    end

    test "delete_correlation/1 deletes the correlation" do
      correlation = correlation_fixture()
      assert {:ok, %Correlation{}} = FGEndpoint.delete_correlation(correlation)
      assert_raise Ecto.NoResultsError, fn -> FGEndpoint.get_correlation!(correlation.id) end
    end

    test "change_correlation/1 returns a correlation changeset" do
      correlation = correlation_fixture()
      assert %Ecto.Changeset{} = FGEndpoint.change_correlation(correlation)
    end
  end
end
