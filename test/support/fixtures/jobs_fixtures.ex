defmodule WorkerDemo.JobsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WorkerDemo.Jobs` context.
  """

  @doc """
  Generate a job.
  """
  def job_fixture(attrs \\ %{}) do
    {:ok, job} =
      attrs
      |> Enum.into(%{
        a: "some a",
        b: "some b",
        name: "some name",
        op: "some op",
        status: "some status"
      })
      |> WorkerDemo.Jobs.create_job()

    job
  end
end
