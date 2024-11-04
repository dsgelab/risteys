# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :risteys,
  ecto_repos: [Risteys.Repo]

# Configures the endpoint
config :risteys, RisteysWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RisteysWeb.ErrorHTML, json: RisteysWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Risteys.PubSub,
  live_view: [signing_salt: "QZq1lOx8"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Ueberauth for authentication and authorization
config :ueberauth, Ueberauth,
  providers: [
    google: {
      Ueberauth.Strategy.Google,
      [
        # Preselects the @finngen.fi account on Google screen
        hd: "finngen.fi",
        # Ask for the minimum needed info
        default_scope: "email",
        # Needed otherwise it will generate the URL with the local IP instead of risteys.finngen.fi
        callback_url: "https://risteys.finregistry.fi/auth/google/callback"
      ]
    }
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id:
    System.get_env("GOOGLE_CLIENT_ID") ||
      raise("Environment variable GOOGLE_CLIENT_ID is missing."),
  client_secret:
    System.get_env("GOOGLE_CLIENT_SECRET") ||
      raise("Environment variable GOOGLE_CLIENT_SECRET is missing.")

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
