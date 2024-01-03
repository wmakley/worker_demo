defmodule WorkerDemo.Worker do
  use GenServer

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job

  alias Phoenix.PubSub

  @type worker() :: GenServer.server()

  def start_link(id, options \\ []) do
    GenServer.start_link(__MODULE__, id, options)
  end

  @spec assign(worker(), %Job{}, delay: integer()) :: :ok | {:error, String.t()}
  def assign(worker, %Job{} = job, delay: delay) when is_integer(delay) do
    GenServer.call(worker, {:assign, job, delay})
  end

  def init(id) do
    state = %{id: id, job: nil, state: :idle}
    {:ok, broadcast_state(state)}
  end

  def handle_call({:assign, %Job{} = job, delay}, _from, state) do
    {:ok, job} =
      Jobs.update_job(job, %{
        status: Job.status_picked_up(),
        picked_up_by: self()
      })

    new_state = %{state | state: :assigned_job, job: job}
    broadcast_state(new_state)
    Process.send_after(self(), :perform_job, delay)
    {:reply, :ok, new_state}
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

    {:noreply, broadcast_state(new_state)}
  end

  defp broadcast_state(state) do
    :ok = PubSub.broadcast(WorkerDemo.PubSub, "workers", {:worker, Node.self(), self(), state})
    state
  end
end
