defmodule Risteys.Repo do
  use Ecto.Repo,
    otp_app: :risteys,
    adapter: Ecto.Adapters.Postgres
end
