defmodule Risteys.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  alias Risteys.Phenocode
  alias Risteys.Repo
  alias Risteys.StatsSex

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Risteys.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Risteys.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Risteys.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Risteys.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  A helper that puts the minimum required data in database for Risteys to run.
  """
  def data_fixture(name) do
    phenocode =
      Phenocode.changeset(%Phenocode{}, %{name: name, longname: "Longname for #{name}"})

    {:ok, phenocode} = Repo.insert(phenocode)

    stats_all =
      StatsSex.changeset(%StatsSex{}, %{
        phenocode_id: phenocode.id,
        sex: 0,
        case_fatality: 0.2,
        mean_age: 40.0,
        median_reoccurence: 2,
        n_individuals: 100,
        prevalence: 0.02,
        reoccurence_rate: 0.001
      })

    {:ok, _stats_all} = Repo.insert(stats_all)
  end
end
