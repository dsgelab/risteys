defmodule Risteys.Repo.Migrations.ChangeCorrelationsAddVariants do
  use Ecto.Migration

  def change do
    alter table(:correlations) do
      add :variants, {:array, :text}
    end
  end
end
