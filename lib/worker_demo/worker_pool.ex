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
      {:ok, _} = start_worker(pool)
    end)

    {:ok, pool}
  end

  @impl true
  def init(_) do
    :pg.get_members(:workers)
    |> Enum.each(&Process.monitor(&1))

    {:ok, %{}}
  end

  @spec get_all_worker_states() :: [{pid(), Map}]
  def get_all_worker_states() do
    :pg.get_members(:workers)
    |> Enum.map(fn worker ->
      {worker,
       Task.async(fn ->
         GenServer.call(worker, :dump_state)
       end)}
    end)
    |> Enum.map(fn {worker, task} ->
      {worker, Task.await(task)}
    end)
  end

  @doc """
  Returns global list of idle workers
  """
  @spec idle_workers() :: [pid()]
  def idle_workers() do
    :pg.get_members(:idle_workers)
  end

  def subscribe_to_worker_states() do
    Phoenix.PubSub.subscribe(WorkerDemo.PubSub, "workers")
  end

  @spec start_worker(GenServer.server()) :: {:ok, pid()}
  def start_worker(worker_pool) do
    GenServer.call(worker_pool, :start_worker)
  end

  @impl true
  def handle_call(:start_worker, _from, state) do
    case DynamicSupervisor.start_child(WorkerPoolSupervisor, Worker) do
      {:ok, child} ->
        Process.monitor(child)

        {:reply, {:ok, child}, state}

      {:error, reason} ->
        Logger.error("#{__MODULE__} error starting worker: #{inspect(reason)}")
    end
  end

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
