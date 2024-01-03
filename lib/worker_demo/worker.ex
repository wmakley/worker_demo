defmodule WorkerDemo.Worker do
  use GenServer

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job

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

  @impl true
  def init(_) do
    state = %{job: nil, state: :idle}
    Logger.debug("#{__MODULE__} #{inspect(self())} starting with state: #{inspect(state)}")

    :ok = :pg.join(:workers, self())
    :ok = :pg.join(:idle_workers, self())

    {:ok, broadcast_state(state)}
  end

  @impl true
  def handle_call(:dump_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:is_idle?, _from, state) do
    {:reply, state.state == :idle, state}
  end

  def handle_call({:assign, %Job{} = job}, _from, state) do
    case state.state do
      :idle ->
        case Jobs.update_job(job, %{
               status: Job.status_picked_up(),
               picked_up_by: inspect(self())
             }) do
          {:ok, job} ->
            :ok = :pg.leave(:idle_workers, self())

            new_state = %{state | state: :assigned_job, job: job}
            broadcast_state(new_state)

            # delay is only for demonstration
            Process.send_after(self(), :perform_job, 3000)

            {:reply, {:ok, job}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :worker_not_idle}, state}
    end
  end

  @impl true
  def handle_info(:perform_job, state) do
    try do
      new_state = %{state | state: :working} |> broadcast_state()
      job = Jobs.get_job!(new_state.job.id)

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
      :pg.join(:idle_workers, self())

      {:noreply, broadcast_state(new_state)}
    rescue
      e ->
        {:ok, _} =
          Jobs.update_job(state.job, %{
            status: Job.status_error(),
            status_details: inspect(e),
            picked_up_by: nil
          })

        # now crash
        raise e
    end
  end

  defp broadcast_state(state) do
    :ok = PubSub.broadcast(WorkerDemo.PubSub, "workers", {:worker, self(), state})
    state
  end
end
