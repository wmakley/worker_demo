defmodule WorkerDemo.WorkerPool do
  @moduledoc """
  Starts :size number of workers under the local WorkerPoolSupervisor,
  provides utility functions for interacting with them, and broadcasts crashes
  to pubsub.
  """

  use GenServer

  alias WorkerDemo.WorkerPoolSupervisor
  alias WorkerDemo.Worker

  require Logger

  def start_link([size: size] = opts) when is_integer(size) do
    Logger.debug("#{__MODULE__}.start_link(#{inspect(opts)})")

    {:ok, pool} = GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

    Enum.each(1..size, fn _ ->
      {:ok, _} = start_worker()
    end)

    {:ok, pool}
  end

  @impl true
  def init(_) do
    :pg.get_members(:workers)
    |> Enum.each(&Process.monitor(&1))

    {:ok, %{}}
  end

  @doc """
  Used by UI on load to display the state of all the workers on the cluster.
  """
  @spec get_all_worker_states() :: [{pid(), Map}]
  def get_all_worker_states() do
    :pg.get_members(:workers)
    |> Enum.map(fn worker ->
      {worker,
       Task.async(fn ->
         Worker.get_state(worker)
       end)}
    end)
    |> Enum.map(fn {worker, task} ->
      {worker, Task.await(task)}
    end)
  end

  @doc """
  Queries all workers on all nodes to find the idle ones. Is there a more
  efficient way? Having a :pg of only idle workers seems like just as much if
  not more network traffic and more error prone.
  """
  @spec idle_workers() :: [pid()]
  def idle_workers() do
    :pg.get_members(:workers)
    |> Enum.map(fn worker ->
      {worker,
       Task.async(fn ->
         Worker.is_idle?(worker)
       end)}
    end)
    |> Enum.map(fn {worker, task} ->
      if Task.await(task) do
        worker
      else
        nil
      end
    end)
    |> Enum.filter(& &1)
  end

  def subscribe_to_worker_states() do
    Phoenix.PubSub.subscribe(WorkerDemo.PubSub, "workers")
  end

  @spec start_worker() :: {:ok, pid()}
  def start_worker() do
    GenServer.call(__MODULE__, :start_worker)
  end

  @doc """
  Called by newly started workers to tell this process to monitor the worker.
  """
  @spec worker_started(pid()) :: :ok
  def worker_started(worker) do
    GenServer.cast(__MODULE__, {:worker_started, worker})
    :ok
  end

  @impl true
  def handle_call(:start_worker, _from, state) do
    case DynamicSupervisor.start_child(WorkerPoolSupervisor, Worker) do
      {:ok, child} ->
        {:reply, {:ok, child}, state}

      {:error, reason} ->
        Logger.error("#{__MODULE__} error starting worker: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def handle_cast({:worker_started, pid}, state) do
    Logger.debug("#{__MODULE__} monitoring worker: #{inspect(pid)}")
    Process.monitor(pid)
    {:noreply, state}
  end

  @doc """
  Re-broadcasts the termination of the worker on pub sub.
  """
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.info("#{__MODULE__} worker #{inspect(pid)} terminated, broadcasting")

    :ok =
      Phoenix.PubSub.broadcast(
        WorkerDemo.PubSub,
        "workers",
        {:worker, pid, :terminated}
      )

    {:noreply, state}
  end
end
