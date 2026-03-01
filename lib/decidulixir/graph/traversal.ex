defmodule Decidulixir.Graph.Traversal do
  @moduledoc """
  Graph traversal algorithms for decision graphs.

  Provides BFS and connected-component traversal following edges
  in either direction. Used by archaeology pivot chains, Loom
  narrative_for_goal, and pulse coverage analysis.
  """

  import Ecto.Query

  alias Decidulixir.Graph.GraphEdge
  alias Decidulixir.Graph.Node
  alias Decidulixir.Repo

  @type direction :: :outgoing | :incoming | :both

  @doc """
  BFS traversal from a start node in the given direction.

  Returns nodes reachable from `start_id` following edges in `direction`:
  - `:outgoing` — follow from_node → to_node
  - `:incoming` — follow to_node → from_node
  - `:both` — follow edges in either direction
  """
  @spec bfs(integer(), direction()) :: [Node.t()]
  def bfs(start_id, direction \\ :outgoing) do
    do_bfs([start_id], MapSet.new([start_id]), direction)
    |> MapSet.to_list()
    |> then(fn ids ->
      Node
      |> where([n], n.id in ^ids)
      |> order_by([n], asc: n.inserted_at)
      |> Repo.all()
    end)
  end

  @doc """
  Returns immediate children of a node (nodes reachable via outgoing edges).
  """
  @spec children(integer()) :: [Node.t()]
  def children(node_id) do
    GraphEdge
    |> where([e], e.from_node_id == ^node_id)
    |> join(:inner, [e], n in Node, on: n.id == e.to_node_id)
    |> select([_e, n], n)
    |> order_by([_e, n], asc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns immediate parents of a node (nodes with outgoing edges to this node).
  """
  @spec parents(integer()) :: [Node.t()]
  def parents(node_id) do
    GraphEdge
    |> where([e], e.to_node_id == ^node_id)
    |> join(:inner, [e], n in Node, on: n.id == e.from_node_id)
    |> select([_e, n], n)
    |> order_by([_e, n], asc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the full connected component containing `node_id`.

  Follows edges in both directions to find all reachable nodes.
  Returns `%{nodes: [...], edges: [...]}`.
  """
  @spec connected_component(integer()) :: %{nodes: [Node.t()], edges: [GraphEdge.t()]}
  def connected_component(node_id) do
    node_ids =
      do_bfs([node_id], MapSet.new([node_id]), :both)
      |> MapSet.to_list()

    nodes =
      Node
      |> where([n], n.id in ^node_ids)
      |> order_by([n], asc: n.inserted_at)
      |> Repo.all()

    edges =
      GraphEdge
      |> where([e], e.from_node_id in ^node_ids and e.to_node_id in ^node_ids)
      |> Repo.all()

    %{nodes: nodes, edges: edges}
  end

  @doc """
  BFS descendants of a node (outgoing only, excludes the start node).
  Used by Loom's narrative_for_goal.
  """
  @spec bfs_descendants(integer()) :: [Node.t()]
  def bfs_descendants(node_id) do
    bfs(node_id, :outgoing)
    |> Enum.reject(fn n -> n.id == node_id end)
  end

  # ── Private ────────────────────────────────────────────────

  defp do_bfs([], visited, _direction), do: visited

  defp do_bfs(frontier, visited, direction) do
    neighbor_ids = fetch_neighbors(frontier, direction)

    new_ids =
      neighbor_ids
      |> Enum.reject(fn id -> MapSet.member?(visited, id) end)

    new_visited = Enum.reduce(new_ids, visited, &MapSet.put(&2, &1))

    do_bfs(new_ids, new_visited, direction)
  end

  defp fetch_neighbors(node_ids, :outgoing) do
    GraphEdge
    |> where([e], e.from_node_id in ^node_ids)
    |> select([e], e.to_node_id)
    |> Repo.all()
  end

  defp fetch_neighbors(node_ids, :incoming) do
    GraphEdge
    |> where([e], e.to_node_id in ^node_ids)
    |> select([e], e.from_node_id)
    |> Repo.all()
  end

  defp fetch_neighbors(node_ids, :both) do
    outgoing =
      GraphEdge
      |> where([e], e.from_node_id in ^node_ids)
      |> select([e], e.to_node_id)
      |> Repo.all()

    incoming =
      GraphEdge
      |> where([e], e.to_node_id in ^node_ids)
      |> select([e], e.from_node_id)
      |> Repo.all()

    Enum.uniq(outgoing ++ incoming)
  end
end
