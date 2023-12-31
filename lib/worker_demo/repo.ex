defmodule WorkerDemo.Repo do
  use Ecto.Repo,
    otp_app: :worker_demo,
    adapter: Ecto.Adapters.Postgres
end
