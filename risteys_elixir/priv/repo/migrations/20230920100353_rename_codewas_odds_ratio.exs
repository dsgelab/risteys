defmodule Risteys.Repo.Migrations.RenameCodewasOddsRatio do
  use Ecto.Migration

  def change do
    rename table(:codewas_codes), :odds_ratio, to: :log10OR
  end
end
