defmodule WorkerDemo.Jobs do
  @moduledoc """
  The Jobs context.
  """

  import Ecto.Query, warn: false
  alias WorkerDemo.Repo

  alias WorkerDemo.Jobs.Job
  alias WorkerDemo.Worker

  alias Phoenix.PubSub

  def subscribe() do
    PubSub.subscribe(WorkerDemo.PubSub, "jobs")
  end

  @doc """
  Returns the list of jobs.

  ## Examples

      iex> list_jobs()
      [%Job{}, ...]

  """
  def list_jobs do
    Repo.all(Job)
  end

  def list_ready_jobs(limit: limit) when is_integer(limit) do
    query =
      from j in Job,
        where: j.status == ^Job.status_ready(),
        select: j,
        order_by: [asc: j.updated_at],
        limit: ^limit

    Repo.all(query)
  end

  @spec assign(%Job{}, Worker.worker()) :: :ok | {:error, term()}
  def assign(job, worker) do
    case Worker.assign(worker, job) do
      :ok ->
        :ok
    end
  end

  @doc """
  Gets a single job.

  Raises `Ecto.NoResultsError` if the Job does not exist.

  ## Examples

      iex> get_job!(123)
      %Job{}

      iex> get_job!(456)
      ** (Ecto.NoResultsError)

  """
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Creates a job.

  ## Examples

      iex> create_job(%{field: value})
      {:ok, %Job{}}

      iex> create_job(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_job(attrs \\ %{}) do
    case %Job{}
         |> Job.changeset(attrs)
         |> Repo.insert() do
      {:ok, job} ->
        :ok = PubSub.broadcast(WorkerDemo.PubSub, "jobs", {:job_insert, job})
        {:ok, job}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a job.

  ## Examples

      iex> update_job(job, %{field: new_value})
      {:ok, %Job{}}

      iex> update_job(job, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_job(%Job{} = job, attrs) do
    case job
         |> Job.changeset(attrs)
         |> Repo.update() do
      {:ok, job} ->
        :ok = PubSub.broadcast(WorkerDemo.PubSub, "jobs", {:job_update, job})
        {:ok, job}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a job.

  ## Examples

      iex> delete_job(job)
      {:ok, %Job{}}

      iex> delete_job(job)
      {:error, %Ecto.Changeset{}}

  """
  def delete_job(%Job{} = job) do
    case Repo.delete(job) do
      {:ok, job} ->
        :ok = PubSub.broadcast(WorkerDemo.PubSub, "jobs", {:job_delete, job})
        {:ok, job}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking job changes.

  ## Examples

      iex> change_job(job)
      %Ecto.Changeset{data: %Job{}}

  """
  def change_job(%Job{} = job, attrs \\ %{}) do
    Job.changeset(job, attrs)
  end
end
