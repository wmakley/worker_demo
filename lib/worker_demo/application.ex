defmodule WorkerDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WorkerDemoWeb.Telemetry,
      WorkerDemo.Repo,
      {DNSCluster, query: Application.get_env(:worker_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WorkerDemo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: WorkerDemo.Finch},
      # Custom distributed worker stuff:
      # WorkerDemo.HordeRegistry,
      # WorkerDemo.HordeSupervisor,
      # WorkerDemo.NodeObserver,
      {WorkerDemo.JobQueue.Starter, scan_interval: 5000},
      {DynamicSupervisor, name: WorkerDemo.WorkerPoolSupervisor, strategy: :one_for_one},
      {WorkerDemo.WorkerPool, size: 2},
      # Start to serve requests, typically the last entry
      WorkerDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WorkerDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WorkerDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
