defmodule WorkerDemoWeb.DashboardLive.Index do
  use WorkerDemoWeb, :live_view

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job
  alias WorkerDemo.WorkerPool

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    :ok = Jobs.subscribe()
    :ok = WorkerPool.subscribe_to_worker_states()

    {:ok,
     socket
     |> assign(:nodes, node_list())
     |> assign(:jobs, Jobs.list_jobs())
     |> stream(:workers, list_workers())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:job, nil)
    |> assign(:page_title, "Workers")
  end

  defp apply_action(socket, :new_job, _params) do
    socket
    |> assign(:page_title, "New Job")
    |> assign(:job, %Job{status: Job.status_new()})
  end

  defp apply_action(socket, :edit_job, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Job")
    |> assign(:job, Jobs.get_job!(id))
  end

  @impl true
  def handle_info({WorkerDemoWeb.DashboardLive.JobForm, {:saved, _job}}, socket) do
    # {:noreply, stream_insert(socket, :jobs, job)}
    # ignore, we will get all updates via pubsub
    {:noreply, socket}
  end

  def handle_info({:job_insert, job}, socket) do
    {:noreply, insert_job(socket, job)}
  end

  def handle_info({:job_update, job}, socket) do
    {:noreply, update_job(socket, job)}
  end

  def handle_info({:job_delete, job}, socket) do
    {:noreply, delete_job(socket, job)}
  end

  def handle_info({:worker, pid, %{} = new_state}, socket) do
    {:noreply, update_worker(socket, pid, new_state)}
  end

  def handle_info({:worker, pid, :terminated}, socket) do
    {:noreply,
     socket
     |> update_worker(pid, %{state: :terminated, job: nil})
     |> put_flash(:error, "Worker #{inspect(pid)} crashed!")}
  end

  @impl true
  def handle_event("reset_job", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)

    {:ok, _} =
      Jobs.update_job(job, %{
        result: nil,
        status: Job.status_ready(),
        status_details: nil,
        picked_up_by: nil
      })

    {:noreply, socket}
  end

  def handle_event("reset_all", _params, socket) do
    :ok =
      Jobs.list_jobs()
      |> Enum.each(fn job ->
        {:ok, _} =
          Jobs.update_job(job, %{
            result: nil,
            status: Job.status_ready(),
            status_details: nil,
            picked_up_by: nil
          })
      end)

    {:noreply, socket}
  end

  def handle_event("delete_job", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)
    {:ok, _} = Jobs.delete_job(job)

    {:noreply, socket}
  end

  defp list_workers() do
    WorkerPool.get_all_worker_states()
    |> Enum.map(fn {pid, state} ->
      to_stream_item(pid, state)
    end)
  end

  defp node_list() do
    [Node.self() | Node.list()]
  end

  defp update_job(socket, job) do
    socket
    |> assign(
      :jobs,
      Enum.map(socket.assigns.jobs, fn j ->
        if j.id == job.id do
          job
        else
          j
        end
      end)
    )
  end

  defp insert_job(socket, job) do
    socket
    |> assign(
      :jobs,
      [job | socket.assigns.jobs]
      |> Enum.sort_by(fn job -> job.id end)
    )
  end

  defp delete_job(socket, job) do
    socket
    |> assign(
      :jobs,
      Enum.filter(socket.assigns.jobs, fn j ->
        j.id != job.id
      end)
    )
  end

  defp update_worker(socket, pid, %{} = worker_state) when is_pid(pid) do
    item = to_stream_item(pid, worker_state)
    Logger.debug("Updating worker state: #{inspect(item)}")

    case worker_state.state do
      # move them to the bottom if they're dead:
      :terminated ->
        socket
        |> stream_delete(:workers, item)
        |> stream_insert(:workers, item, at: -1)

      _ ->
        socket
        |> stream_insert(:workers, item, at: 0)
    end
  end

  # convert a worker pid and state to stream item for display, using pid as id
  defp to_stream_item(pid, worker_state) when is_pid(pid) do
    worker_state
    |> Map.put(:id, inspect(pid))
    |> Map.put(:pid, pid)
  end

  defp job_id(worker_state) do
    case worker_state.job do
      nil ->
        nil

      %{id: id} ->
        id
    end
  end
end
