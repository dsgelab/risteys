use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :risteys, RisteysWeb.Endpoint,
  check_origin: [
    "https://risteys.finngen.fi",
    "https://r3.risteys.finngen.fi",
    "https://r4.risteys.finngen.fi",
    "https://r5.risteys.finngen.fi",
    "https://testing.risteys.finngen.fi",
    "https://staging-dot-finngen-risteys.ew.r.appspot.com",
    "https://testing-dot-finngen-risteys.ew.r.appspot.com",
    "https://*.ew.r.appspot.com",
  ],
  secret_key_base: "4l5EqefpSp/vc4EOfvI/g7lsB2JzkxPFge0ezlcmdloHeyCu0NtoVA4VSw7buP8u"

# Configure your database
config :risteys, Risteys.Repo,
  username: "postgres",
  password: "8x!mnC*VZkWU5K#ZiaG5bQTCJpzH#Fhr$$x(^A^BBvi5oTFijNnhpzwz)#M!ACBq",

  # Each Risteys flavor (e.g. R7-blue, R7-green, R6) accesses a
  # different database.
  # Here we set this database name by referring to the system
  # environment variable RISTEYS_FLAVOR. This variable will be
  # populated from app.yaml when it starts on Google App Engine.
  # This means it is *not set* at build time when running "gcloud app deploy".
  #
  # Somehow, this present file is interpreted on "mix local.hex
  # --force", which is a step of the Dockerfile build on "glcoud app
  # deploy".
  # This variable is not used at build time, but it must be parsable
  # by Elixir otherwise it will throw an error and "gcloud app deploy"
  # will fail.
  # Thus we use the default value of "" which prevent build time failure.
  # The correct value will be taken at run time from the system
  # environment variable RISTEYS_FLAVOR.
  #
  # TODO: use mix releases and runtime config to simplify this
  #       https://hexdocs.pm/phoenix/releases.html#runtime-configuration
  database: "risteys_" <> System.get_env("RISTEYS_FLAVOR", ""),
  hostname: "35.205.171.61",
  pool_size: 10
