defmodule WorkerDemo.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :a, :integer
      add :b, :integer
      add :op, :string
      add :result, :integer
      add :status, :string, null: false, default: "New Job"
      add :status_details, :string
      add :picked_up_by, :string
      add :attempts, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:jobs, [:status])
  end
end
