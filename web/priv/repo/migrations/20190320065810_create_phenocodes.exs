defmodule Risteys.Repo.Migrations.CreatePhenocodes do
  use Ecto.Migration

  def change do
    create table(:phenocodes) do
      add :code, :string
      add :longname, :string
      add :hd_codes, {:array, :string}
      add :cod_codes, {:array, :string}

      timestamps()
    end

    create unique_index(:phenocodes, [:code])
  end
end
