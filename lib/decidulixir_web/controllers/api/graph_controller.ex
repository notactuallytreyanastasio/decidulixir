defmodule DecidulixirWeb.API.GraphController do
  @moduledoc "JSON API for decision graph data."
  use DecidulixirWeb, :controller

  alias Decidulixir.Graph

  def index(conn, params) do
    filters = build_filters(params)
    graph = Graph.get_graph(filters)

    data = %{
      nodes: Enum.map(graph.nodes, &serialize_node/1),
      edges: Enum.map(graph.edges, &serialize_edge/1),
      stats: Graph.graph_stats()
    }

    json(conn, data)
  end

  def show(conn, %{"id" => id_str}) do
    case Integer.parse(id_str) do
      {id, ""} ->
        case Graph.get_node(id) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not found"})

          node ->
            data = %{
              node: serialize_node(node),
              incoming_edges: Graph.edges_to(id) |> Enum.map(&serialize_edge/1),
              outgoing_edges: Graph.edges_from(id) |> Enum.map(&serialize_edge/1)
            }

            json(conn, data)
        end

      _ ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid ID"})
    end
  end

  def stats(conn, _params) do
    json(conn, %{
      stats: Graph.graph_stats(),
      by_type: Graph.node_counts_by_type()
    })
  end

  defp build_filters(params) do
    []
    |> maybe_filter(:node_type, params["type"])
    |> maybe_filter(:status, params["status"])
    |> maybe_filter(:branch, params["branch"])
    |> maybe_filter(:search, params["search"])
  end

  defp maybe_filter(acc, _key, nil), do: acc
  defp maybe_filter(acc, _key, ""), do: acc

  defp maybe_filter(acc, key, val) when key in [:node_type, :status] do
    [{key, String.to_existing_atom(val)} | acc]
  end

  defp maybe_filter(acc, key, val), do: [{key, val} | acc]

  defp serialize_node(n) do
    %{
      id: n.id,
      change_id: n.change_id,
      node_type: n.node_type,
      title: n.title,
      description: n.description,
      status: n.status,
      metadata: n.metadata,
      inserted_at: n.inserted_at,
      updated_at: n.updated_at
    }
  end

  defp serialize_edge(e) do
    %{
      id: e.id,
      from_node_id: e.from_node_id,
      to_node_id: e.to_node_id,
      edge_type: e.edge_type,
      weight: e.weight,
      rationale: e.rationale,
      inserted_at: e.inserted_at
    }
  end
end
