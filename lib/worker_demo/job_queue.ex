defmodule WorkerDemo.JobQueue do
  @moduledoc """
  Global job queue. For this demo there should be only one. It works by
  registering yourself as waiting for a job, then the queue will periodically
  assign work to any waiting processes. This avoids multiple processes
  scanning the table unnecessarily.

  If the waiting worker process goes down, the work will simply be assigned
  to next process in the queue.
  """
  use GenServer

  alias Phoenix.PubSub

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job
  alias WorkerDemo.Worker
  alias WorkerDemo.WorkerPool

  @type job_queue() :: GenServer.server()

  require Logger

  @spec start_link([scan_interval: integer()], GenServer.options()) :: GenServer.on_start()
  def start_link(init_arg, opts \\ []) do
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  def subscribe() do
    PubSub.subscribe(WorkerDemo.PubSub, "job_queue")
  end

  @doc """
  Add yourself to the list of workers waiting for work, where "worker" can be
  a pid or via tuple. Via tuple is necessary for distributed registry to work.
  """
  @spec wait_for_job(Worker.worker()) :: :ok | {:error, term()}
  def wait_for_job(worker) do
    GenServer.call({:global, __MODULE__}, {:wait_for_job, worker})
  end

  def init(opts) do
    Logger.debug("#{__MODULE__} starting with opts: #{inspect(opts)}")

    scan_interval = Keyword.get(opts, :scan_interval, 5000)

    idle_workers = WorkerPool.idle_workers()
    Logger.debug("#{__MODULE__} enqueuing #{length(idle_workers)} idle workers")

    queue =
      idle_workers
      |> Enum.reduce(:queue.new(), fn worker, queue ->
        :queue.in(worker, queue)
      end)

    # start scanning jobs table every 5 seconds
    Logger.info("starting job scan every #{scan_interval}ms")
    broadcast({:job_queue, :started})

    Process.send_after(self(), :scan_for_ready_jobs, scan_interval)
    # workers will ask for work as they come online
    {:ok, %{worker_queue: queue, scan_interval: scan_interval}}
  end

  def handle_call({:wait_for_job, worker}, _, state) do
    Logger.debug("#{__MODULE__} adding worker to queue: #{inspect(worker)}")

    queue = state.worker_queue

    state =
      if :queue.member(worker, queue) do
        state
      else
        %{
          state
          | worker_queue: :queue.in(worker, state.worker_queue)
        }
      end

    {:reply, :ok, state}
  end

  # Internal function run every 5 seconds
  def handle_info(:scan_for_ready_jobs, state) do
    broadcast({:job_queue, :scanning})
    Logger.debug("#{__MODULE__} scanning for ready jobs...")
    Process.sleep(3000)

    queue = state.worker_queue

    case :queue.len(queue) do
      0 ->
        Logger.debug("#{__MODULE__} no workers in queue")
        {:noreply, state}

      num ->
        # not bothering with transaction since all status changes from
        # ready -> something else must go through this process
        ready_jobs = Jobs.list_ready_jobs(limit: num)

        # for every ready job, try to dequeue a worker pid and assign it to a worker:
        broadcast({:job_queue, :dispatching})
        Process.sleep(3000)
        queue = dispatch_jobs(ready_jobs, queue)

        broadcast({:job_queue, :idle})
        Process.send_after(self(), :scan_for_ready_jobs, state.scan_interval)
        {:noreply, %{state | worker_queue: queue}}
    end
  end

  defp dispatch_jobs([job | rest], queue) do
    case :queue.out(queue) do
      {{:value, worker}, q2} ->
        Logger.debug(
          "#{__MODULE__} attempting to assign Job ID #{job.id} to Worker #{inspect(worker)}"
        )

        case Worker.assign(worker, job) do
          {:ok, _} ->
            :ignore

          {:error, reason} ->
            Logger.error(
              "#{__MODULE__} error assigning #{inspect(job)} to Worker #{inspect(worker)}: #{inspect(reason)}"
            )

            {:ok, _} =
              Jobs.update_job(job, %{
                status: Job.status_error(),
                attempts: job.attempts + 1
              })
        end

        dispatch_jobs(rest, q2)

      {:empty, q2} ->
        q2
    end
  end

  defp dispatch_jobs([], queue) do
    queue
  end

  defp broadcast(msg) do
    :ok = PubSub.broadcast(WorkerDemo.PubSub, "job_queue", msg)
  end
end
