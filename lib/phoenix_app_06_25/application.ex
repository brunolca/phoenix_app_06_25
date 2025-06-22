defmodule PhoenixApp0625.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhoenixApp0625Web.Telemetry,
      PhoenixApp0625.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:phoenix_app_06_25, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:phoenix_app_06_25, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhoenixApp0625.PubSub},
      {Oban, Application.fetch_env!(:phoenix_app_06_25, Oban)},
      # Start to serve requests, typically the last entry
      PhoenixApp0625Web.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixApp0625.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixApp0625Web.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
