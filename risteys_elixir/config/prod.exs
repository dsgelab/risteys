import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
config :risteys, RisteysWeb.Endpoint,
  http: [:inet6, port: System.get_env("PORT") || 8080],
  url: [host: "risteys.finregistry.fi", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  # Enable gzip compression. Note that phx.digest MUST be run in order
  # to generate the gzip files that will be used.
  gzip: true

# Do not print debug messages in production
config :logger, level: :info


# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section and set your `:url` port to 443:
#
#     config :risteys, RisteysWeb.Endpoint,
#       ...
#       url: [host: "example.com", port: 443],
#       https: [
#         :inet6,
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
#       ]
#
# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers. This means old browsers
# and clients may not be supported. You can set it to
# `:compatible` for wider support.
#
# `:keyfile` and `:certfile` expect an absolute path to the key
# and cert in disk or a relative path inside priv, for example
# "priv/ssl/server.key". For all supported SSL configuration
# options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
#
# We also recommend setting `force_ssl` in your endpoint, ensuring
# no data is ever sent via http, always redirecting to https:
#
#     config :risteys, RisteysWeb.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.

# ## Using releases (distillery)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :risteys, RisteysWeb.Endpoint, server: true
#
# Note you can't rely on `System.get_env/1` when using releases.
# See the releases documentation accordingly.

# Google OAuth authentication
config :ueberauth, Ueberauth,
  providers: [
    google: {
      Ueberauth.Strategy.Google,
      [
	hd: "finngen.fi",  # preselects the @finngen.fi account on Google screen
	default_scope: "email",  # ask for the minimum needed info
	callback_url: "https://risteys.finngen.fi/auth/google/callback",  # needed otherwise it will generate the URL with the local IP instead of risteys.finngen.fi
      ]
    }
  ]

# Google OAuth client credentials must NOT be written here.
# We use environment variables instead.
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Finally import the config/prod.secret.exs which should be versioned
# separately.
import_config "newristeys_prod.secret.exs"
