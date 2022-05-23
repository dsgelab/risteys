defmodule Risteys.Repo.Migrations.AlterPhenocodeChangeOmitInteger do
  use Ecto.Migration


  def up do
    alter table(:phenocodes) do
      modify :omit, :text
      modify :sex, :text
      modify :hd_mainonly, :text
      modify :cod_mainonly, :text
      modify :canc_behav, :text
      add :canc_topo_excl, :text
    end
  end

  # Need to use remove/add duos, since cannot cast from {boolean, integer} to string
  def down do
    alter table(:phenocodes) do
      remove :omit
      add :omit, :boolean

      remove :sex
      add :sex, :integer
      
      remove :hd_mainonly
      add :hd_mainonly, :boolean

      remove :cod_mainonly
      add :cod_mainonly, :boolean

      remove :canc_behav
      add :canc_behav, :integer

      remove :canc_topo_excl
    end
  end
end
