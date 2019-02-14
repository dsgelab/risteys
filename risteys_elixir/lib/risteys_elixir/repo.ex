defmodule Risteys.Repo do
  use Ecto.Repo,
    otp_app: :risteys_elixir,
    adapter: Ecto.Adapters.Postgres
end
