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
  @spec enqueue_worker(Worker.worker()) :: :ok | {:error, term()}
  def enqueue_worker(worker) do
    GenServer.call({:global, __MODULE__}, {:enqueue_worker, worker})
  end

  def init(opts) do
    Logger.debug("#{__MODULE__} starting with opts: #{inspect(opts)}")

    scan_interval = Keyword.get(opts, :scan_interval, 5000)

    Logger.info("#{__MODULE__} starting worker and job scan every #{scan_interval}ms")
    broadcast({:job_queue, :started})

    timer = Process.send_after(self(), :scan, scan_interval)

    {:ok, %{scan_interval: scan_interval, timer: timer}}
  end

  # Internal function run every interval ms
  def handle_info(:scan, state) do
    broadcast({:job_queue, :scanning})
    Logger.debug("#{__MODULE__} scanning for workers and jobs...")

    filled_queue = enqueue_idle_workers(:queue.new())
    # Logger.debug("#{__MODULE__} filled worker queue: #{inspect(filled_queue)}")

    new_state =
      case :queue.peek(filled_queue) do
        :empty ->
          Logger.debug("#{__MODULE__} no workers in queue")
          state

        {:value, _} ->
          # not bothering with transaction since all status changes from
          # ready -> something else must go through this process
          ready_jobs = Jobs.list_ready_jobs(limit: 100)

          # for every ready job, try to dequeue a worker pid and assign it to a worker:
          broadcast({:job_queue, :dispatching})
          dispatch_jobs(ready_jobs, filled_queue)

          broadcast({:job_queue, :idle})
          state
      end

    timer = Process.send_after(self(), :scan, state.scan_interval)
    {:noreply, %{new_state | timer: timer}}
  end

  defp enqueue_idle_workers(queue) do
    idle_workers = WorkerPool.idle_workers()
    Logger.debug("#{__MODULE__} enqueuing idle workers: #{inspect(idle_workers)}")

    idle_workers
    |> Enum.reduce(queue, fn worker, queue ->
      :queue.in(worker, queue)
    end)
  end

  defp dispatch_jobs([job | rest], queue) do
    case :queue.out(queue) do
      {{:value, worker}, q2} ->
        Logger.info(
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
                status_details: inspect(reason),
                picked_up_by: nil,
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
