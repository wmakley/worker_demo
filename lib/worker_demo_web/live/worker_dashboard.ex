defmodule WorkerDemoWeb.Live.WorkerDashboard do
  use WorkerDemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:nodes, [Node.self() | Node.list()])}
  end
end
