defmodule WorkerDemo.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  def status_new, do: "New Job"
  def status_ready, do: "Ready"
  def status_picked_up, do: "Picked Up"
  def status_in_progress, do: "In Progress"
  def status_error, do: "Error"
  def status_complete, do: "Complete"

  def statuses do
    [
      status_new(),
      status_ready(),
      status_picked_up(),
      status_in_progress(),
      status_error(),
      status_complete()
    ]
  end

  schema "jobs" do
    field :a, :integer
    field :b, :integer
    field :op, :string
    field :result, :integer
    field :status, :string
    field :status_details, :string
    field :picked_up_by, :string
    field :attempts, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :a,
      :b,
      :op,
      :result,
      :status,
      :status_details,
      :picked_up_by,
      :attempts
    ])
    |> validate_required([:a, :b, :op, :status])
    |> validate_inclusion(:status, statuses())
    |> validate_inclusion(:op, ["+", "-", "*", "/", "%"])
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
  end
end
