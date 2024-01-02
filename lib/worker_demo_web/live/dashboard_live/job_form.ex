defmodule WorkerDemoWeb.DashboardLive.JobForm do
  use WorkerDemoWeb, :live_component

  alias WorkerDemo.Jobs
  alias WorkerDemo.Jobs.Job

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage job records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="job-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:a]} type="text" label="a" />
        <.input field={@form[:op]} type="text" label="op" />
        <.input field={@form[:b]} type="text" label="b" />
        <.input field={@form[:status]} type="select" options={Job.statuses()} label="Status" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Job</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{job: job} = assigns, socket) do
    changeset = Jobs.change_job(job)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"job" => job_params}, socket) do
    changeset =
      socket.assigns.job
      |> Jobs.change_job(job_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"job" => job_params}, socket) do
    save_job(socket, socket.assigns.action, job_params)
  end

  defp save_job(socket, :edit_job, job_params) do
    case Jobs.update_job(socket.assigns.job, job_params) do
      {:ok, job} ->
        notify_parent({:saved, job})

        {:noreply,
         socket
         |> put_flash(:info, "Job updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_job(socket, :new_job, job_params) do
    case Jobs.create_job(job_params) do
      {:ok, job} ->
        notify_parent({:saved, job})

        {:noreply,
         socket
         |> put_flash(:info, "Job created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
