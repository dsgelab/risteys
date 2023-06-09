defmodule Risteys.Repo.Migrations.AlterPhenocodeDropCodeIndex do
  use Ecto.Migration

  def up do
    # The index should be on :name but was missed in a previous renaming
    drop_if_exists index(:phenocodes, [:code], name: "phenocodes_code_index")
  end

  def down do
    create index(:phenocodes, [:name], name: "phenocodes_code_index")
  end
end
