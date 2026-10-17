defmodule ParcEpique.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParcEpiqueWeb.Telemetry,
      ParcEpique.Repo,
      {DNSCluster, query: Application.get_env(:parc_epique, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ParcEpique.PubSub},
      {Oban, Application.fetch_env!(:parc_epique, Oban)},
      # Start a worker by calling: ParcEpique.Worker.start_link(arg)
      # {ParcEpique.Worker, arg},
      # Start to serve requests, typically the last entry
      ParcEpiqueWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ParcEpique.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ParcEpiqueWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
