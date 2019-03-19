defmodule Risteys.Repo.Migrations.CreatePhenocodes do
  use Ecto.Migration

  def change do
    create table(:phenocodes, primary_key: false) do
      add :code, :string, primary_key: true
      add :longname, :string
      add :hd_codes, {:array, :string}
      add :cod_codes, {:array, :string}

      timestamps()
    end
  end
end
