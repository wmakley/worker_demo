defmodule WorkerDemo.JobQueue.Starter do
  use GenServer

  require Logger

  alias WorkerDemo.JobQueue

  def start_link(job_queue_opts \\ []) do
    GenServer.start_link(__MODULE__, job_queue_opts, name: __MODULE__)
  end

  @impl true
  def init(job_queue_opts) do
    pid = start_and_monitor(job_queue_opts)

    {:ok, {pid, job_queue_opts}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _reason}, {pid, job_queue_opts} = _state) do
    {:noreply, {start_and_monitor(job_queue_opts), job_queue_opts}}
  end

  defp start_and_monitor(job_queue_opts) do
    pid =
      case JobQueue.start_link(job_queue_opts, name: {:global, JobQueue}) do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid
      end

    Process.monitor(pid)

    pid
  end
end
