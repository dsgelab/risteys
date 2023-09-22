defmodule Risteys.Repo.Migrations.AlterCodewasCasesControlsNonNil do
  use Ecto.Migration

  # We have to create an "up" and a "down" function since a single "change" one
  # would not be able to rolled back.
  #
  # In this migration we only want to make the following changes:
  # - n_matched_cases: not nullable
  # - n_matched_controls: not nullable
  #
  # But we have to drop the the whole table to do so, because changing the
  # columns in-place to non-nullable would create problem on "up" if the
  # table currently has nil values.

  def up do
    drop table(:codewas_codes)
    drop_if_exists index(:codewas_codes, [:fg_endpoint_id, :code, :vocabulary])

    create table(:codewas_codes) do
      add :code, :string, null: false
      add :vocabulary, :string, null: false
      add :description, :string, null: false
      add :odds_ratio, :float, null: false
      add :nlog10p, :float, null: false

      # !! Here the important part: make these 2 columns non-nullable
      add :n_matched_cases, :integer, null: false
      add :n_matched_controls, :integer, null: false

      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:codewas_codes, [:fg_endpoint_id, :code, :vocabulary])
  end

  def down do
    drop table(:codewas_codes)
    drop_if_exists index(:codewas_codes, [:fg_endpoint_id, :code, :vocabulary])

    create table(:codewas_codes) do
      add :code, :string, null: false
      add :vocabulary, :string, null: false
      add :description, :string, null: false
      add :odds_ratio, :float, null: false
      add :nlog10p, :float, null: false
      add :n_matched_cases, :integer
      add :n_matched_controls, :integer
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:codewas_codes, [:fg_endpoint_id, :code, :vocabulary])
  end
end
