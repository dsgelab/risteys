# NOTE: Data import and DB migrations are NOT handled in this script,
# they must be done separately from a VM on Google Compute Engine
# beforehand.

# NOTE: if some failure occurs during the Webpack step, try to remove
# the "node_modules" directory on your local computer.


FROM elixir:1.11

# Setup app environment
ADD . /app
WORKDIR /app

ENV MIX_ENV prod

# Installing Node.js
# from https://github.com/nodesource/distributions/blob/master/README.md#debinstall
# and use the LTS version
RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs

# Installing Phoenix
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install --force hex phx_new 1.5.9

RUN mix deps.get --only prod

# Make JS and CSS assets
WORKDIR assets
RUN npm prune
RUN npm install
RUN npm audit fix
# webpack needs both NODE_ENV and --mode,
# see https://github.com/webpack/webpack/issues/7074.
ENV NODE_ENV production
RUN ./node_modules/webpack/bin/webpack.js --mode production
WORKDIR ..

# Build the whole Elixir app
RUN mix compile
RUN mix phx.digest

ENTRYPOINT ["mix", "phx.server"]
