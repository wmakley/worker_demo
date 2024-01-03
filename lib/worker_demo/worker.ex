defmodule WorkerDemo.Worker do
  use GenServer

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job
  alias WorkerDemo.JobQueue

  alias Phoenix.PubSub

  require Logger

  @type worker() :: GenServer.server()

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, nil, options)
  end

  @spec assign(worker(), %Job{}) :: {:ok, %Job{}} | {:error, String.t()}
  def assign(worker, %Job{} = job) do
    GenServer.call(worker, {:assign, job})
  end

  def init(_) do
    state = %{job: nil, state: :idle}
    Logger.debug("#{__MODULE__} #{inspect(self())} starting with state: #{inspect(state)}")
    :ok = JobQueue.wait_for_job(self())
    {:ok, broadcast_state(state)}
  end

  def handle_call(:dump_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:is_idle?, _from, state) do
    {:reply, state.state == :idle, state}
  end

  def handle_call({:assign, %Job{} = job}, _from, state) do
    case Jobs.update_job(job, %{
           status: Job.status_picked_up(),
           picked_up_by: inspect(self())
         }) do
      {:ok, job} ->
        new_state = %{state | state: :assigned_job, job: job}
        broadcast_state(new_state)
        Process.send_after(self(), :perform_job, 3000)
        {:reply, {:ok, job}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(:perform_job, state) do
    new_state = %{state | state: :working} |> broadcast_state()
    job = Jobs.get_job!(new_state.job.id)

    # TODO: any failure should set job to error

    {:ok, job} =
      Jobs.update_job(job, %{
        status: Job.status_in_progress()
      })

    Process.sleep(5000)

    a = job.a
    b = job.b

    result =
      case job.op do
        "+" ->
          a + b

        "-" ->
          a - b

        "*" ->
          a * b

        "/" ->
          a / b
      end

    {:ok, _} =
      Jobs.update_job(job, %{
        status: Job.status_complete(),
        result: result
      })

    new_state = %{new_state | job: nil, state: :idle}
    :ok = JobQueue.wait_for_job(self())

    {:noreply, broadcast_state(new_state)}
  end

  def broadcast_state(state) do
    :ok = PubSub.broadcast(WorkerDemo.PubSub, "workers", {:worker, self(), state})
    state
  end
end
