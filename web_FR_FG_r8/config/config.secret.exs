use Mix.Config

# Configures the endpoint
config :risteys, RisteysWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "MegC7Zaj5poNfvT/wdTWxGpFhMwJ0rUdtgs1rpfSdvyB7WyaUWVQxe9PmhdFhgRH",
  render_errors: [view: RisteysWeb.ErrorView, accepts: ~w(html json)],
## TODO pubsub_server: Risteys.PubSub
## TODO live_view: [signing_salt: "LOK5DcM/VW6ilkG6SJtffGeXvBnmhpLw"]
  # pubsub: [name: Risteys.PubSub, adapter: Phoenix.PubSub.PG2] #commented out this because :pubsub key in RisteysWeb.Endpoint is deprecated.
  pubsub_server: Risteys.PubSub
