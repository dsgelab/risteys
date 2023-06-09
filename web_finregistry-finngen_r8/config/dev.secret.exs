import Config

# Configure your database
config :risteys, Risteys.Repo,
  username: "risteys",
  password: "helloristeys",
  database: "risteys_dev_r8",
  hostname: "localhost",
  pool_size: 10
