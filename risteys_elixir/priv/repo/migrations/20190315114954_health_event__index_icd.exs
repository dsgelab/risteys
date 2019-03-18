defmodule Risteys.Repo.Migrations.HealthEventIndexIcd do
  use Ecto.Migration

  def change do
    create index("health_events", [:icd])
  end
end
