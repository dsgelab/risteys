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

  alias Risteys.HealthEvent
  alias Risteys.Phenocode
  alias Risteys.Repo

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
  def data_fixture(code, count) do
    phenocode = %Phenocode{
      code: code,
      longname: "",
      tags: "",
      level: "",
      omit: false,
      sex: 1,
      include: "",
      pre_conditions: "",
      conditions: "",
      outpat_icd: "",
      hd_mainonly: false,
      hd_icd_10: [""],
      hd_icd_9: [""],
      hd_icd_8: "",
      hd_icd_10_excl: "",
      hd_icd_9_excl: "",
      hd_icd_8_excl: "",
      cod_mainonly: false,
      cod_icd_10: [""],
      cod_icd_9: [""],
      cod_icd_8: "",
      cod_icd_10_excl: "",
      cod_icd_9_excl: "",
      cod_icd_8_excl: "",
      oper_nom: "",
      oper_hl: "",
      oper_hp1: "",
      oper_hp2: "",
      kela_reimb: "",
      kela_reimb_icd: [""],
      kela_atc_needother: "",
      kela_atc: "",
      canc_topo: "",
      canc_morph: "",
      canc_behav: 0,
      special: "",
      version: "",
      source: "",
      pheweb: false
    }

    {:ok, phenocode} = Repo.insert(phenocode)

    for i <- 1..count do
      sex =
        case rem(i, 2) do
          0 -> 1
          1 -> 2
        end

      health_event = %HealthEvent{
        age: 50.0,
        dateevent: ~D[2000-01-01],
        eid: i,
        sex: sex
      }

      assoc = Ecto.build_assoc(phenocode, :health_events, health_event)
      {:ok, _} = Repo.insert(assoc)
    end
  end
end
