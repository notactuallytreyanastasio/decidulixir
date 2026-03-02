defmodule Decidulixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DecidulixirWeb.Telemetry,
      Decidulixir.Repo,
      {DNSCluster, query: Application.get_env(:decidulixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Decidulixir.PubSub},
      Decidulixir.CLI.Supervisor,
      DecidulixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Decidulixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DecidulixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
