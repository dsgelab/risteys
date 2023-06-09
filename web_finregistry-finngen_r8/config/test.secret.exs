use Mix.Config

# Configure your database
config :risteys, Risteys.Repo,
  username: "risteys",
  password: "helloristeys",
  database: "risteys_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
