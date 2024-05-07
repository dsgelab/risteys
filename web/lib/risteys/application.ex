defmodule Risteys.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RisteysWeb.Telemetry,
      # Start the Ecto repository
      Risteys.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Risteys.PubSub},
      # Start the Endpoint (http/https)
      RisteysWeb.Endpoint
      # Start a worker by calling: Risteys.Worker.start_link(arg)
      # {Risteys.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Risteys.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RisteysWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
