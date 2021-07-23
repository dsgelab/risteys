FROM elixir

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install --force hex phx_new 1.4.1

ADD . /app
WORKDIR /app

RUN mix deps.get --only prod

ENV MIX_ENV prod
RUN mix compile
RUN mix phx.digest

ENTRYPOINT ["mix", "phx.server"]
