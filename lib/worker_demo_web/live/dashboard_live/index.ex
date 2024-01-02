defmodule WorkerDemoWeb.DashboardLive.Index do
  use WorkerDemoWeb, :live_view

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workers")
     |> assign(:nodes, node_list())
     |> stream(:jobs, Jobs.list_jobs())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:job, nil)
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
  def handle_info({WorkerDemoWeb.DashboardLive.JobForm, {:saved, job}}, socket) do
    {:noreply, stream_insert(socket, :jobs, job)}
  end

  @impl true
  def handle_event("delete_job", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)
    {:ok, _} = Jobs.delete_job(job)

    {:noreply, stream_delete(socket, :jobs, job)}
  end

  defp node_list() do
    [Node.self() | Node.list()]
  end
end
