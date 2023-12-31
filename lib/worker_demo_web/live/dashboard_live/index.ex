defmodule WorkerDemoWeb.DashboardLive.Index do
  use WorkerDemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Workers") |> assign(:nodes, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Workers")
    |> assign(:nodes, node_list())
  end

  defp node_list() do
    [Node.self() | Node.list()]
  end
end
