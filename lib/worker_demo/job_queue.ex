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

  alias WorkerDemo.Jobs
  alias WorkerDemo.Worker

  @type job_queue() :: GenServer.server()

  require Logger

  def start_link(init_arg, opts \\ []) do
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  @doc """
  Add yourself to the list of workers waiting for work, where "worker" can be
  a pid or via tuple. Via tuple is necessary for distributed registry to work.
  """
  @spec wait_for_job(job_queue(), Worker.worker()) :: :ok | {:error, term()}
  def wait_for_job(queue, worker) do
    GenServer.call(queue, {:wait_for_job, worker})
  end

  def init(_) do
    scan_interval = 5000
    # start scanning jobs table every 5 seconds
    Logger.info("starting job scan every #{scan_interval}ms")
    Process.send_after(self(), :scan_for_ready_jobs, scan_interval)
    # workers will ask for work as they come online
    {:ok, %{worker_queue: :queue.new(), scan_interval: scan_interval}}
  end

  def handle_call({:wait_for_job, worker}, _, state) do
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
    Logger.debug("scanning for ready jobs...")
    queue = state.worker_queue

    # not bothering with transaction since all status changes from
    # ready -> something else must go through this process
    ready_jobs = Jobs.list_ready_jobs(limit: :queue.len(queue))

    # for every ready job, try to dequeue a worker pid and assign it to a worker:
    queue = dispatch_jobs(ready_jobs, queue)

    Process.send_after(self(), :scan_for_ready_jobs, state.scan_interval)
    {:noreply, %{state | worker_queue: queue}}
  end

  defp dispatch_jobs([job | rest], queue) do
    case :queue.out(queue) do
      {{:value, worker}, q2} ->
        :ok = Jobs.assign(job, worker)

        # TODO: error handling if worker is not running or assignment fails: assign job to next worker or reset status

        dispatch_jobs(rest, q2)

      {:empty, q2} ->
        q2
    end
  end

  defp dispatch_jobs([], queue) do
    queue
  end
end
