defmodule WorkerDemo.WorkerPool do
  alias WorkerDemo.WorkerPoolSupervisor
  alias WorkerDemo.Worker

  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary,
      shutdown: 500
    }
  end

  def start_link([size: size] = opts) when is_integer(size) do
    Logger.debug("#{__MODULE__}.start_link(#{inspect(opts)})")

    Enum.each(1..size, fn _ ->
      start_worker()
    end)

    :ignore
  end

  def start_worker() do
    DynamicSupervisor.start_child(WorkerPoolSupervisor, Worker)
  end
end
