defmodule DecidulixirWeb.GraphLive.Index do
  @moduledoc "Main graph viewer — lists nodes with filters and stats."
  use DecidulixirWeb, :live_view

  alias Decidulixir.Graph

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Decidulixir.PubSub, "graph:updates")
    end

    socket =
      socket
      |> assign(:page_title, "Decision Graph")
      |> assign(:filters, %{})
      |> assign(:node_count, 0)
      |> assign(:stats, %{nodes: 0, edges: 0, by_type: %{}})
      |> stream(:nodes, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filters = parse_filters(params)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign_graph_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    params =
      filter_params
      |> Enum.reject(fn {_k, v} -> v == "" end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/graph?#{params}")}
  end

  @impl true
  def handle_info({:graph_updated, _change}, socket) do
    {:noreply, assign_graph_data(socket)}
  end

  defp assign_graph_data(socket) do
    filters = build_query_filters(socket.assigns.filters)
    nodes = Graph.list_nodes(filters)
    stats = Graph.graph_stats()
    by_type = Graph.node_counts_by_type()

    socket
    |> stream(:nodes, nodes, reset: true)
    |> assign(:stats, Map.put(stats, :by_type, by_type))
    |> assign(:node_count, length(nodes))
  end

  defp parse_filters(params) do
    %{}
    |> maybe_put("status", params["status"])
    |> maybe_put("type", params["type"])
    |> maybe_put("branch", params["branch"])
    |> maybe_put("search", params["search"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp build_query_filters(filters) do
    []
    |> maybe_add_filter(:status, filters["status"])
    |> maybe_add_filter(:node_type, filters["type"])
    |> maybe_add_filter(:branch, filters["branch"])
    |> maybe_add_filter(:search, filters["search"])
  end

  defp maybe_add_filter(acc, _key, nil), do: acc
  defp maybe_add_filter(acc, _key, ""), do: acc

  defp maybe_add_filter(acc, key, val) when key in [:status, :node_type] do
    [{key, String.to_existing_atom(val)} | acc]
  end

  defp maybe_add_filter(acc, key, val), do: [{key, val} | acc]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Decision Graph</h1>
          <span class="text-sm opacity-60">{@node_count} nodes</span>
        </div>

        <DecidulixirWeb.GraphComponents.stats_panel stats={@stats} />

        <form phx-change="filter" class="flex flex-wrap gap-2">
          <select name="filter[type]" class="select select-bordered select-sm">
            <option value="">All types</option>
            <option :for={t <- ~w(goal decision option action outcome observation revisit)} value={t} selected={@filters["type"] == t}>
              {t}
            </option>
          </select>

          <select name="filter[status]" class="select select-bordered select-sm">
            <option value="">All statuses</option>
            <option :for={s <- ~w(active superseded abandoned pending completed rejected)} value={s} selected={@filters["status"] == s}>
              {s}
            </option>
          </select>

          <input
            type="text"
            name="filter[search]"
            value={@filters["search"]}
            placeholder="Search..."
            class="input input-bordered input-sm w-48"
            phx-debounce="300"
          />

          <input
            type="text"
            name="filter[branch]"
            value={@filters["branch"]}
            placeholder="Branch..."
            class="input input-bordered input-sm w-36"
            phx-debounce="300"
          />
        </form>

        <div class="space-y-2" id="nodes-list" phx-update="stream">
          <.link
            :for={{dom_id, node} <- @streams.nodes}
            id={dom_id}
            navigate={~p"/graph/#{node.id}"}
            class="block hover:opacity-80 transition-opacity"
          >
            <DecidulixirWeb.GraphComponents.node_card node={node} />
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
