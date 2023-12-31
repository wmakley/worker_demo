defmodule WorkerDemo.JobsTest do
  use WorkerDemo.DataCase

  alias WorkerDemo.Jobs

  describe "jobs" do
    alias WorkerDemo.Jobs.Job

    import WorkerDemo.JobsFixtures

    @invalid_attrs %{name: nil, status: nil, op: nil, a: nil, b: nil}

    test "list_jobs/0 returns all jobs" do
      job = job_fixture()
      assert Jobs.list_jobs() == [job]
    end

    test "get_job!/1 returns the job with given id" do
      job = job_fixture()
      assert Jobs.get_job!(job.id) == job
    end

    test "create_job/1 with valid data creates a job" do
      valid_attrs = %{name: "some name", status: "some status", op: "some op", a: "some a", b: "some b"}

      assert {:ok, %Job{} = job} = Jobs.create_job(valid_attrs)
      assert job.name == "some name"
      assert job.status == "some status"
      assert job.op == "some op"
      assert job.a == "some a"
      assert job.b == "some b"
    end

    test "create_job/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Jobs.create_job(@invalid_attrs)
    end

    test "update_job/2 with valid data updates the job" do
      job = job_fixture()
      update_attrs = %{name: "some updated name", status: "some updated status", op: "some updated op", a: "some updated a", b: "some updated b"}

      assert {:ok, %Job{} = job} = Jobs.update_job(job, update_attrs)
      assert job.name == "some updated name"
      assert job.status == "some updated status"
      assert job.op == "some updated op"
      assert job.a == "some updated a"
      assert job.b == "some updated b"
    end

    test "update_job/2 with invalid data returns error changeset" do
      job = job_fixture()
      assert {:error, %Ecto.Changeset{}} = Jobs.update_job(job, @invalid_attrs)
      assert job == Jobs.get_job!(job.id)
    end

    test "delete_job/1 deletes the job" do
      job = job_fixture()
      assert {:ok, %Job{}} = Jobs.delete_job(job)
      assert_raise Ecto.NoResultsError, fn -> Jobs.get_job!(job.id) end
    end

    test "change_job/1 returns a job changeset" do
      job = job_fixture()
      assert %Ecto.Changeset{} = Jobs.change_job(job)
    end
  end
end
