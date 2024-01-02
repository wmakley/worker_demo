defmodule WorkerDemoWeb.DashboardLive.Index do
  use WorkerDemoWeb, :live_view

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job

  @impl true
  def mount(_params, _session, socket) do
    :ok = Jobs.subscribe()

    {:ok,
     socket
     |> assign(:nodes, node_list())
     |> assign(:jobs, Jobs.list_jobs())}
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

  @impl true
  def handle_event("delete_job", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)
    {:ok, _} = Jobs.delete_job(job)

    {:noreply, socket}
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
    |> assign(:jobs, [job | socket.assigns.jobs])
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
end
